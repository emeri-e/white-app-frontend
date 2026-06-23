#!/usr/bin/env python3
"""
Download the official NudeNet 320n ONNX model and convert to TFLite.
The model is a YOLOv8n-based detector with 17 body-part classes.
"""
import os
import sys
import subprocess
import hashlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.dirname(SCRIPT_DIR)
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "model_output")
FLUTTER_ASSETS = os.path.join(FRONTEND_DIR, "assets", "models")
ANDROID_ASSETS = os.path.join(FRONTEND_DIR, "android", "app", "src", "main", "assets", "models")

ONNX_FILENAME = "320n.onnx"
TFLITE_FILENAME = "nudenet_320n.tflite"


def install_deps():
    """Install required Python packages."""
    deps = ["nudenet", "onnx", "onnx2tf", "tensorflow", "tf-keras", "onnx-graphsurgeon", "sng4onnx"]
    print(f"Installing dependencies: {', '.join(deps)}")
    subprocess.check_call([
        sys.executable, "-m", "pip", "install", "--quiet", "--upgrade"
    ] + deps)


def download_onnx_model():
    """Download the NudeNet ONNX model via the nudenet package."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    onnx_path = os.path.join(OUTPUT_DIR, ONNX_FILENAME)

    if os.path.exists(onnx_path) and os.path.getsize(onnx_path) > 1_000_000:
        print(f"ONNX model already exists at {onnx_path} ({os.path.getsize(onnx_path)} bytes)")
        return onnx_path

    print("Downloading NudeNet 320n model via nudenet package...")
    # The nudenet package downloads the model on first use
    from nudenet import NudeDetector
    detector = NudeDetector()
    
    # Find the cached ONNX model
    import nudenet
    nudenet_dir = os.path.dirname(nudenet.__file__)
    
    # The model is typically at ~/.NudeNet/320n.onnx or within the package
    possible_paths = [
        os.path.expanduser("~/.NudeNet/320n.onnx"),
        os.path.join(nudenet_dir, "320n.onnx"),
    ]
    
    source_path = None
    for p in possible_paths:
        if os.path.exists(p):
            source_path = p
            break
    
    if source_path is None:
        # Search more broadly
        import glob
        home_results = glob.glob(os.path.expanduser("~/**/*320n*.onnx"), recursive=True)
        if home_results:
            source_path = home_results[0]
    
    if source_path is None:
        raise FileNotFoundError(
            "Could not locate the NudeNet ONNX model. "
            "Expected at ~/.NudeNet/320n.onnx"
        )
    
    import shutil
    shutil.copy2(source_path, onnx_path)
    print(f"ONNX model copied to {onnx_path} ({os.path.getsize(onnx_path)} bytes)")
    return onnx_path


def convert_to_tflite(onnx_path):
    """Convert ONNX model to TFLite using onnx2tf."""
    tflite_output_dir = os.path.join(OUTPUT_DIR, "tflite_output")
    os.makedirs(tflite_output_dir, exist_ok=True)
    
    print("Converting ONNX to TFLite via onnx2tf...")
    subprocess.check_call([
        sys.executable, "-m", "onnx2tf",
        "-i", onnx_path,
        "-o", tflite_output_dir,
        "-oiqt",   # INT8 quantization for smaller model (optional, remove for float32)
        "-nuo",    # Non-unique operations handling  
    ])
    
    # Find the generated .tflite file
    import glob
    tflite_files = glob.glob(os.path.join(tflite_output_dir, "**/*.tflite"), recursive=True)
    
    # Prefer the float32 model for accuracy
    float_models = [f for f in tflite_files if "float32" in f.lower()]
    if float_models:
        return float_models[0]
    
    if tflite_files:
        # Pick the largest one (likely float32)
        return max(tflite_files, key=os.path.getsize)
    
    raise FileNotFoundError(f"No .tflite files found in {tflite_output_dir}")


def deploy_model(tflite_path):
    """Copy the converted model to Flutter and Android asset directories."""
    import shutil
    
    # Compute hash
    with open(tflite_path, "rb") as f:
        sha256 = hashlib.sha256(f.read()).hexdigest()
    
    size_mb = os.path.getsize(tflite_path) / (1024 * 1024)
    print(f"\nConverted model: {tflite_path}")
    print(f"  Size: {size_mb:.2f} MB")
    print(f"  SHA-256: {sha256}")
    
    # Deploy to Flutter assets
    os.makedirs(FLUTTER_ASSETS, exist_ok=True)
    dst_flutter = os.path.join(FLUTTER_ASSETS, TFLITE_FILENAME)
    shutil.copy2(tflite_path, dst_flutter)
    print(f"  → Deployed to {dst_flutter}")
    
    # Deploy to Android native assets
    os.makedirs(ANDROID_ASSETS, exist_ok=True)
    dst_android = os.path.join(ANDROID_ASSETS, TFLITE_FILENAME)
    shutil.copy2(tflite_path, dst_android)
    print(f"  → Deployed to {dst_android}")
    
    return sha256


def inspect_model(tflite_path):
    """Print the input/output tensor shapes for implementation reference."""
    try:
        import tensorflow as tf
        interpreter = tf.lite.Interpreter(model_path=tflite_path)
        interpreter.allocate_tensors()
        
        print("\n=== TFLite Model Inspection ===")
        print("Input tensors:")
        for t in interpreter.get_input_details():
            print(f"  {t['name']}: shape={t['shape']}, dtype={t['dtype']}")
        
        print("Output tensors:")
        for t in interpreter.get_output_details():
            print(f"  {t['name']}: shape={t['shape']}, dtype={t['dtype']}")
        print("===============================\n")
    except Exception as e:
        print(f"Warning: Could not inspect model: {e}")


def main():
    print("=" * 60)
    print("NudeNet 320n → TFLite Conversion Pipeline")
    print("=" * 60)
    
    install_deps()
    onnx_path = download_onnx_model()
    tflite_path = convert_to_tflite(onnx_path)
    inspect_model(tflite_path)
    sha256 = deploy_model(tflite_path)
    
    print("\n✓ Conversion complete!")
    print(f"  Model SHA-256: {sha256}")
    print("  Both Flutter and Android assets updated.")


if __name__ == "__main__":
    main()
