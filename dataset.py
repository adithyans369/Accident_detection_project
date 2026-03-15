import numpy as np
import pandas as pd

np.random.seed(42)

SAMPLES_PER_CLASS = 100

def generate_features(mean_vals, std_vals, label, n):
    data = {
        "peak_acc": np.random.normal(mean_vals[0], std_vals[0], n),
        "mean_acc": np.random.normal(mean_vals[1], std_vals[1], n),
        "std_acc": np.random.normal(mean_vals[2], std_vals[2], n),
        "acc_range": np.random.normal(mean_vals[3], std_vals[3], n),
        "jerk_mean": np.random.normal(mean_vals[4], std_vals[4], n),
        "gyro_mean": np.random.normal(mean_vals[5], std_vals[5], n),
        "gyro_std": np.random.normal(mean_vals[6], std_vals[6], n),
        "gyro_range": np.random.normal(mean_vals[7], std_vals[7], n),
        "energy_acc": np.random.normal(mean_vals[8], std_vals[8], n),
        "energy_gyro": np.random.normal(mean_vals[9], std_vals[9], n),
        "label": label
    }
    return pd.DataFrame(data)

# ---------- Class definitions ----------

# 0️⃣ Normal motion
normal = generate_features(
    mean_vals=[12, 9.8, 0.8, 3, 0.5, 0.3, 0.2, 0.8, 900, 40],
    std_vals=[2, 0.5, 0.2, 1, 0.2, 0.1, 0.05, 0.2, 100, 10],
    label=0,
    n=SAMPLES_PER_CLASS
)

# 1️⃣ Sudden brake
brake = generate_features(
    mean_vals=[18, 11, 2, 7, 2, 0.8, 0.3, 1.5, 1600, 90],
    std_vals=[3, 1, 0.5, 2, 0.5, 0.2, 0.1, 0.3, 200, 20],
    label=1,
    n=SAMPLES_PER_CLASS
)

# 2️⃣ Pothole / bump
pothole = generate_features(
    mean_vals=[16, 10.5, 1.8, 6, 1.5, 0.6, 0.25, 1.2, 1400, 70],
    std_vals=[2.5, 0.8, 0.4, 1.5, 0.4, 0.15, 0.08, 0.25, 180, 15],
    label=2,
    n=SAMPLES_PER_CLASS
)

# 3️⃣ Accident (high impact)
accident = generate_features(
    mean_vals=[28, 15, 4, 18, 6, 3, 2, 8, 4500, 900],
    std_vals=[4, 2, 1, 4, 1.5, 0.8, 0.5, 2, 800, 200],
    label=3,
    n=SAMPLES_PER_CLASS
)

# ---------- Combine dataset ----------
dataset = pd.concat([normal, brake, pothole, accident], ignore_index=True)

# Shuffle dataset
dataset = dataset.sample(frac=1).reset_index(drop=True)

# Save
dataset.to_csv("accident_dataset_multiclass.csv", index=False)

print("Dataset generated successfully!")
print(dataset.head())
print("\nClass distribution:")
print(dataset["label"].value_counts())