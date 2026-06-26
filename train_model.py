"""
SeñaLink AI — Script de Entrenamiento del Modelo LSTM
=====================================================
Entrena un clasificador de secuencias de pose (33 landmarks x 4)
+ face mesh (468 puntos 3D) usando los datos grabados desde
sign_training_page.dart y subidos a Firestore.

Dimensiones por frame:
  - Pose: 33 landmarks × 4 (x, y, z, likelihood) = 132
  - Face Mesh: 468 puntos × 3 (x, y, z)          = 1404
  - Total por frame                               = 1536

Salida:
  - assets/models/senalink_model.tflite  (modelo para la app)
  - assets/models/labels.txt             (etiquetas)
"""

import os, json, sys, math, random
from datetime import datetime

import numpy as np

# Firebase es opcional — si no está o no hay key, usamos datos sintéticos
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    _HAS_FIREBASE = True
except ImportError:
    _HAS_FIREBASE = False

# ─── TensorFlow / Keras ──────────────────────────────────────────
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # menos ruido
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

# ──────────────────────────────────────────────────────────────────
# CONFIGURACIÓN — edita si es necesario
# ──────────────────────────────────────────────────────────────────
FIREBASE_KEY = r"C:\Users\shant\Downloads\senalink-ai-firebase-adminsdk-fbsvc-4beec361e9.json"
MODEL_DIR    = "assets/models"
MODEL_NAME   = "senalink_model"
SEQ_LEN      = 45        # frames por secuencia (padding/truncation)
EPOCHS       = 50
BATCH_SIZE   = 16
VALID_SPLIT  = 0.15
LEARNING_RATE = 0.001

# 33 landmarks de MediaPipe / ML Kit (orden de PoseLandmarkType)
LANDMARK_NAMES = [
    "nose", "leftEyeInner", "leftEye", "leftEyeOuter",
    "rightEyeInner", "rightEye", "rightEyeOuter", "leftEar",
    "rightEar", "mouthLeft", "mouthRight", "leftShoulder",
    "rightShoulder", "leftElbow", "rightElbow", "leftWrist",
    "rightWrist", "leftPinky", "rightPinky", "leftIndex",
    "rightIndex", "leftThumb", "rightThumb", "leftHip",
    "rightHip", "leftKnee", "rightKnee", "leftAnkle",
    "rightAnkle", "leftHeel", "rightHeel", "leftFootIndex",
    "rightFootIndex",
]
N_LANDMARKS = len(LANDMARK_NAMES)        # 33
FEAT_PER_LANDMARK = 4                     # x, y, z, likelihood
POSE_DIM = N_LANDMARKS * FEAT_PER_LANDMARK  # 132

# Face Mesh: 468 puntos 3D (x, y, z)
N_FACE_POINTS = 468
FEAT_PER_FACE = 3
FACE_DIM = N_FACE_POINTS * FEAT_PER_FACE  # 1404

FEAT_DIM = POSE_DIM + FACE_DIM            # 1536

# ──────────────────────────────────────────────────────────────────
# 1.  CARGAR DATOS DESDE FIRESTORE  (o sintéticos si no hay)
# ──────────────────────────────────────────────────────────────────
def load_firestore_data():
    """Devuelve listas (X, y, categories, users) desde Firestore."""
    if not _HAS_FIREBASE:
        print("[!] firebase-admin no está instalado.")
        print("[i] Usaré datos sintéticos de demostración.")
        return None, None, None, None

    if not os.path.isfile(FIREBASE_KEY):
        print(f"[!] No encuentro la clave Firebase en:\n    {FIREBASE_KEY}")
        print("[i] Usaré datos sintéticos de demostración.")
        return None, None, None, None

    try:
        cred = credentials.Certificate(FIREBASE_KEY)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
    except Exception as e:
        print(f"[!] Error inicializando Firebase: {e}")
        print("[i] Usaré datos sintéticos de demostración.")
        return None, None, None, None

    docs = db.collection("datasets").stream()
    X, y, cats, users = [], [], [], []
    count = 0
    for doc in docs:
        d = doc.to_dict()
        seq = d.get("secuencia")
        label = d.get("etiqueta")
        cat = d.get("categoria", "")
        user = d.get("usuario", "")
        if not seq or not label:
            continue
        # cada frame debe ser lista de FEAT_DIM valores
        clean = [np.array(f, dtype=np.float32) for f in seq
                 if isinstance(f, (list, tuple)) and len(f) == FEAT_DIM]
            if not clean:
                continue
            # si la secuencia viene con datos viejos (132 features),
            # la rellenamos con ceros para face mesh
            if clean[0].shape[-1] == POSE_DIM:
                clean = [np.concatenate([f, np.zeros(FACE_DIM, dtype=np.float32)]) for f in clean]
            X.append(np.array(clean))
        y.append(label.strip())
        cats.append(cat)
        users.append(user)
        count += 1

    print(f"[✓] Cargados {count} ejemplos desde Firestore")
    print(f"    Etiquetas únicas: {len(set(y))}")
    return X, y, cats, users


# ──────────────────────────────────────────────────────────────────
# 2.  DATOS SINTÉTICOS DE DEMOSTRACIÓN
# ──────────────────────────────────────────────────────────────────
def generate_synthetic_data(n_samples=200):
    """Genera secuencias sintéticas de pose para probar el pipeline."""
    labels = [
        "hola", "gracias", "adiós", "por favor", "ayuda",
        "agua", "comida", "casa", "médico", "emergencia",
        "dolor", "fiebre", "hospital", "amigo", "familia",
    ]
    X, y = [], []
    for _ in range(n_samples):
        label = random.choice(labels)
        length = random.randint(20, SEQ_LEN + 10)
        seq = []
        # simulamos una "trayectoria" de pose + face
        base = np.random.randn(FEAT_DIM).astype(np.float32) * 0.5
        for i in range(length):
            t = i / max(length - 1, 1)
            # cada etiqueta tiene un patrón sinusoidal distinto
            phase = labels.index(label) * 0.7
            noise = np.random.randn(FEAT_DIM).astype(np.float32) * 0.08
            frame = base + np.sin(t * 6 + phase) * 0.6 + noise
            # likelihood de pose entre 0.5 y 1.0 (solo primeros 132)
            for j in range(3, POSE_DIM, 4):
                frame[j] = np.clip(frame[j], 0.5, 1.0)
            seq.append(frame)
        X.append(np.array(seq))
        y.append(label)
    print(f"[i] Generados {n_samples} ejemplos sintéticos")
    print(f"    Etiquetas: {len(set(y))} únicas")
    return X, y, None, None


# ──────────────────────────────────────────────────────────────────
# 3.  PREPROCESAMIENTO: PADDING / TRUNCAMIENTO + ONE-HOT
# ──────────────────────────────────────────────────────────────────
def pad_sequences_list(seqs, maxlen, pad_value=0.0):
    """Padding/truncation manual (sin depender de tf.keras.preprocessing)."""
    out = []
    for s in seqs:
        l = len(s)
        if l >= maxlen:
            out.append(s[:maxlen])
        else:
            pad = np.full((maxlen - l, FEAT_DIM), pad_value, dtype=np.float32)
            out.append(np.concatenate([s, pad], axis=0))
    return np.array(out, dtype=np.float32)


def build_label_encoder(labels):
    """Mapea etiquetas string → índices enteros."""
    unique = sorted(set(labels))
    str2int = {lbl: i for i, lbl in enumerate(unique)}
    int2str = {i: lbl for i, lbl in enumerate(unique)}
    return unique, str2int, int2str


# ──────────────────────────────────────────────────────────────────
# 4.  ARQUITECTURA DEL MODELO (LSTM Bidirectional)
# ──────────────────────────────────────────────────────────────────
def build_model(n_classes):
    inputs = keras.Input(shape=(SEQ_LEN, FEAT_DIM), name="pose_sequence")

    x = layers.Bidirectional(layers.LSTM(128, return_sequences=True))(inputs)
    x = layers.Dropout(0.35)(x)

    x = layers.Bidirectional(layers.LSTM(64, return_sequences=True))(x)
    x = layers.Dropout(0.35)(x)

    x = layers.Bidirectional(layers.LSTM(32))(x)
    x = layers.Dropout(0.25)(x)

    x = layers.Dense(64, activation="relu")(x)
    x = layers.Dropout(0.2)(x)

    outputs = layers.Dense(n_classes, activation="softmax", name="prediction")(x)

    model = keras.Model(inputs, outputs, name="senalink_lstm")
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


# ──────────────────────────────────────────────────────────────────
# 5.  ENTRENAMIENTO
# ──────────────────────────────────────────────────────────────────
def train(X_raw, y_raw):
    # codificar etiquetas
    unique_labels, str2int, int2str = build_label_encoder(y_raw)
    n_classes = len(unique_labels)
    print(f"[i] Clases: {n_classes}")
    print(f"    {unique_labels}")

    y_int = np.array([str2int[lbl] for lbl in y_raw], dtype=np.int32)

    # padding
    X_pad = pad_sequences_list(X_raw, SEQ_LEN)
    print(f"[i] Shape X: {X_pad.shape}")
    print(f"[i] Shape y: {y_int.shape}")

    # normalizar por landmarks (opcional)
    mean = X_pad.mean(axis=(0, 1), keepdims=True)
    std  = X_pad.std(axis=(0, 1), keepdims=True) + 1e-8
    X_norm = (X_pad - mean) / std

    # shuffle
    idx = np.random.permutation(len(X_norm))
    X_norm, y_int = X_norm[idx], y_int[idx]

    # split train / val
    split = int(len(X_norm) * (1 - VALID_SPLIT))
    X_train, X_val = X_norm[:split], X_norm[split:]
    y_train, y_val = y_int[:split], y_int[split:]
    print(f"[i] Train: {len(X_train)}  Val: {len(X_val)}")

    # modelo
    model = build_model(n_classes)
    model.summary()

    # callbacks
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor="val_loss", patience=10, restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss", factor=0.5, patience=5, min_lr=1e-6
        ),
    ]

    # entrenar
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=callbacks,
        verbose=1,
    )

    # evaluar
    val_loss, val_acc = model.evaluate(X_val, y_val, verbose=0)
    print(f"\n[✓] Precisión en validación: {val_acc:.3f}")

    return model, history, (mean, std)


# ──────────────────────────────────────────────────────────────────
# 6.  CONVERTIR A TFLite
# ──────────────────────────────────────────────────────────────────
def convert_to_tflite(model, mean, std, unique_labels):
    os.makedirs(MODEL_DIR, exist_ok=True)

    # cuantización con soporte para ops LSTM
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    converter._experimental_lower_tensor_list_ops = False
    converter.inference_input_type = tf.float32
    converter.inference_output_type = tf.float32

    tflite_model = converter.convert()

    tflite_path = os.path.join(MODEL_DIR, f"{MODEL_NAME}.tflite")
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    size_mb = os.path.getsize(tflite_path) / (1024 * 1024)
    print(f"[✓] Modelo TFLite guardado: {tflite_path}  ({size_mb:.2f} MB)")

    # guardar metadatos de normalización como JSON
    meta = {
        "mean": mean.flatten().tolist() if hasattr(mean, "flatten") else mean,
        "std": std.flatten().tolist() if hasattr(std, "flatten") else std,
        "seq_len": SEQ_LEN,
        "feat_dim": FEAT_DIM,
        "labels": unique_labels,
        "trained_at": datetime.now().isoformat(),
    }
    meta_path = os.path.join(MODEL_DIR, f"{MODEL_NAME}_meta.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(f"[✓] Metadatos guardados: {meta_path}")

    # labels.txt
    labels_path = os.path.join(MODEL_DIR, "labels.txt")
    with open(labels_path, "w", encoding="utf-8") as f:
        f.write("\n".join(unique_labels))
    print(f"[✓] Labels guardados: {labels_path}  ({len(unique_labels)} clases)")


# ──────────────────────────────────────────────────────────────────
# 7.  MAIN
# ──────────────────────────────────────────────────────────────────
def main():
    print("=" * 55)
    print("  SeñaLink AI — Entrenamiento de Modelo LSTM")
    print("=" * 55)

    # cargar datos
    X_raw, y_raw, cats, users = load_firestore_data()
    if X_raw is None or len(X_raw) < 5:
        print("[i] Pocos o ningún dato real. Usando sintéticos...")
        X_raw, y_raw, _, _ = generate_synthetic_data(n_samples=300)

    # entrenar
    model, history, norm_stats = train(X_raw, y_raw)

    # convertir
    convert_to_tflite(model, *norm_stats, sorted(set(y_raw)))

    print("\n" + "=" * 55)
    print("  ¡Listo! Copia los archivos a la carpeta assets/models/")
    print("  y úsalos desde Flutter con Tflite.loadModel()")
    print("=" * 55)


if __name__ == "__main__":
    main()
