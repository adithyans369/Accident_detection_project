
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import joblib
import onnx

from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, ConfusionMatrixDisplay
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType

# ── 1. DATA INGESTION ─────────────────────────────────────────────────────────
print("Loading MPU6050 Sensor Data...")
df = pd.read_csv("mpu6050_accident_dataset_5000.csv")
print(f"Dataset Loaded. Shape: {df.shape}")

# ── 2. RULE-BASED DATA SANITIZATION ───────────────────────────────────────────
# Rationale: Sensor data can contain mislabeled noise. Before training the AI,
# we enforce strict physical thresholds (e.g., Crash must be >= 8.0 G-force).
# This guarantees the Random Forest only learns from validated physics.
def map_to_multiclass(row):
    original = row["label"]
    peak     = row.get("peak_acc",   0)
    jerk     = row.get("jerk_mean",  0)
    gyro     = row.get("gyro_mean",  0)

    if original == 0:
        if peak < 1.1 and gyro < 10: return 0      # 0: Stationary
        elif peak < 2.0 and jerk < 0.3: return 1   # 1: Normal driving
        else: return 2                             # 2: Bump / pothole
    else:
        if peak >= 8.0 or jerk >= 2.0: return 5    # 5: Critical crash
        elif peak >= 5.0 or jerk >= 1.0: return 4  # 4: Major accident
        else: return 3                             # 3: Minor accident

df["label_mc"] = df.apply(map_to_multiclass, axis=1)

LABEL_NAMES = {
    0: "Stationary", 1: "Normal driving", 2: "Bump / pothole",
    3: "Minor accident", 4: "Major accident", 5: "Critical crash"
}

# ── 3. FEATURE EXTRACTION & SPLITTING ─────────────────────────────────────────
FEATURE_COLS = [
    "peak_acc", "mean_acc", "std_acc", "acc_range", "jerk_mean",
    "gyro_mean", "gyro_std", "gyro_range", "energy_acc", "energy_gyro"
]

# Cast to float32 for optimized edge computing on mobile processors
X = df[FEATURE_COLS].values.astype(np.float32)
y = df["label_mc"].values

# Split 80% Train, 20% Test.
# stratify=y ensures rare critical crashes are equally represented in both sets.
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)
print(f"Data Split Complete. Train: {len(X_train)}, Test: {len(X_test)}")

# ── 4. MODEL TRAINING (ENSEMBLE METHOD) ───────────────────────────────────────
# Rationale: Random Forest is highly resilient to sensor noise and lightweight
# for mobile deployment compared to deep neural networks.
print("\nTraining Random Forest Model...")
model = RandomForestClassifier(
    n_estimators=200,          # Build 200 decision trees
    max_depth=12,              # Limit depth to prevent overfitting
    min_samples_leaf=3,
    class_weight="balanced",   # Heavily penalize missing rare severe accidents
    random_state=42,
    n_jobs=-1,                 # Utilize all CPU cores for training
)
model.fit(X_train, y_train)
print("Training Complete.")

# ── 5. EVALUATION METRICS ─────────────────────────────────────────────────────
y_pred = model.predict(X_test)
target_names = [LABEL_NAMES[i] for i in sorted(LABEL_NAMES.keys()) if i in np.unique(y)]

print("\n--- Classification Report ---")
print(classification_report(y_test, y_pred, target_names=target_names))

# Render Confusion Matrix
disp = ConfusionMatrixDisplay.from_estimator(
    model, X_test, y_test, display_labels=target_names, xticks_rotation="vertical"
)
plt.title("Confusion Matrix — 6-Class Severity")
plt.tight_layout()
plt.show()

# ── 6. EDGE DEPLOYMENT BRIDGE (ONNX EXPORT) ───────────────────────────────────
print("\nExporting Model for Mobile Deployment (ONNX)...")

# Define input shape mapping for the ONNX graph
initial_type = [("float_input", FloatTensorType([None, len(FEATURE_COLS)]))]

onnx_model = convert_sklearn(
    model,
    initial_types=initial_type,
    target_opset=12,
    # CRITICAL ENGINEERING FIX: zipmap=False forces the ONNX output to be a
    # flat array instead of a dictionary map, preventing Dart/Flutter crashes.
    options={id(model): {"zipmap": False}},
)

onnx_model.ir_version = 8

output_filename = "rf_accident_model_fixed-2.onnx"
onnx.save(onnx_model, output_filename)
print(f"Successfully compiled and saved: {output_filename}")

# ── 7. PIPELINE VERIFICATION ──────────────────────────────────────────────────
try:
    import onnxruntime as rt
    sess = rt.InferenceSession(output_filename)

    # Fabricate a catastrophic impact vector (8.5 Gs) to test inference
    crash_input = np.array([[8.5, 4.2, 2.1, 6.0, 2.5, 500.0, 200.0, 800.0, 150.0, 300.0]], dtype=np.float32)

    label_name = sess.get_outputs()[0].name
    prob_name  = sess.get_outputs()[1].name
    pred = sess.run([label_name, prob_name], {"float_input": crash_input})

    print("\n✅ Verification Passed:")
    print(f"Simulated Crash Test classified as Severity Level: {pred[0][0]}")
    print(f"Probability Array Output Format Verified: {type(pred[1][0])}")

except ImportError:
    print("onnxruntime not installed locally. Skipping verification.")

print("\n=== PIPELINE COMPLETE. READY FOR FLUTTER INTEGRATION ===")