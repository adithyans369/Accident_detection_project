'''import numpy as np
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

# Class definitions.

# Class 0: normal motion.
normal = generate_features(
    mean_vals=[12, 9.8, 0.8, 3, 0.5, 0.3, 0.2, 0.8, 900, 40],
    std_vals=[2, 0.5, 0.2, 1, 0.2, 0.1, 0.05, 0.2, 100, 10],
    label=0,
    n=SAMPLES_PER_CLASS
)

# Class 1: sudden brake.
brake = generate_features(
    mean_vals=[18, 11, 2, 7, 2, 0.8, 0.3, 1.5, 1600, 90],
    std_vals=[3, 1, 0.5, 2, 0.5, 0.2, 0.1, 0.3, 200, 20],
    label=1,
    n=SAMPLES_PER_CLASS
)

# Class 2: pothole or bump.
pothole = generate_features(
    mean_vals=[16, 10.5, 1.8, 6, 1.5, 0.6, 0.25, 1.2, 1400, 70],
    std_vals=[2.5, 0.8, 0.4, 1.5, 0.4, 0.15, 0.08, 0.25, 180, 15],
    label=2,
    n=SAMPLES_PER_CLASS
)

# Class 3: high impact accident.
accident = generate_features(
    mean_vals=[28, 15, 4, 18, 6, 3, 2, 8, 4500, 900],
    std_vals=[4, 2, 1, 4, 1.5, 0.8, 0.5, 2, 800, 200],
    label=3,
    n=SAMPLES_PER_CLASS
)

# Combine all classes.
dataset = pd.concat([normal, brake, pothole, accident], ignore_index=True)

# Shuffle the rows.
dataset = dataset.sample(frac=1).reset_index(drop=True)

# Save the dataset.
dataset.to_csv("accident_dataset_multiclass.csv", index=False)

print("Dataset generated successfully!")
print(dataset.head())
print("\nClass distribution:")
print(dataset["label"].value_counts())'''

import numpy as np
import pandas as pd

np.random.seed(42)

samples_per_class = 833   # About 5000 rows for 6 classes.
data = []

def generate_features(acc_min, acc_max, gyro_min, gyro_max, label):

    peak_acc = np.random.uniform(acc_min, acc_max)
    mean_acc = peak_acc * np.random.uniform(0.4, 0.8)
    std_acc = peak_acc * np.random.uniform(0.1, 0.3)
    acc_range = peak_acc * np.random.uniform(0.6, 1.2)

    jerk_mean = np.random.uniform(acc_min/2, acc_max/2)

    gyro_mean = np.random.uniform(gyro_min, gyro_max)
    gyro_std = gyro_mean * np.random.uniform(0.1, 0.4)
    gyro_range = gyro_mean * np.random.uniform(0.5, 1.2)

    energy_acc = peak_acc**2 * np.random.uniform(0.5, 2)
    energy_gyro = gyro_mean**2 * np.random.uniform(0.5, 2)

    return [
        peak_acc,
        mean_acc,
        std_acc,
        acc_range,
        jerk_mean,
        gyro_mean,
        gyro_std,
        gyro_range,
        energy_acc,
        energy_gyro,
        label
    ]

# Value ranges for each class.
ranges = [
    (0.1, 1.2, 1, 30, 0),      # Normal.
    (1.0, 2.5, 20, 80, 1),     # Bump.
    (2.0, 4.5, 60, 150, 2),    # Hard brake.
    (4.0, 7.0, 120, 300, 3),   # Minor accident.
    (6.0, 10.0, 250, 600, 4),  # Major accident.
    (9.0, 16.0, 500, 1500, 5)  # Critical crash.
]

for acc_min, acc_max, gyro_min, gyro_max, label in ranges:
    for _ in range(samples_per_class):
        data.append(generate_features(acc_min, acc_max, gyro_min, gyro_max, label))

columns = [
    "peak_acc",
    "mean_acc",
    "std_acc",
    "acc_range",
    "jerk_mean",
    "gyro_mean",
    "gyro_std",
    "gyro_range",
    "energy_acc",
    "energy_gyro",
    "label"
]

df = pd.DataFrame(data, columns=columns)

df.to_csv("mpu6050_accident_dataset_5000.csv", index=False)

print("Dataset created:", df.shape)
