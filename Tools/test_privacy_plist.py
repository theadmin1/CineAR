import plistlib
from pathlib import Path
import tempfile

from validate_privacy_plist import validate


VALID = {
    "CFBundleIdentifier": "com.cinear.virtualproduction",
    "NSCameraUsageDescription": "Kamera, odanızı LiDAR ile taramak ve sanal dekorları göstermek için kullanılır.",
    "NSMicrophoneUsageDescription": "Mikrofon, AR çekimi sırasında ses kaydetmek için kullanılır.",
    "NSSpeechRecognitionUsageDescription": "Konuşma tanıma, sesli CGI komutlarını anlamak için kullanılır.",
    "NSLocalNetworkUsageDescription": "Yerel ağ, aynı ağdaki derinlik sunucusuna bağlanmak için kullanılır.",
}


with tempfile.TemporaryDirectory(prefix="cinear-plist-tests-") as directory:
    path = Path(directory) / "Info.plist"
    with path.open("wb") as handle:
        plistlib.dump(VALID, handle, fmt=plistlib.FMT_BINARY)
    assert validate(path, "com.cinear.virtualproduction") == []

    for key in VALID:
        broken = dict(VALID)
        broken.pop(key)
        with path.open("wb") as handle:
            plistlib.dump(broken, handle)
        assert validate(path, "com.cinear.virtualproduction"), key

    vague = dict(VALID)
    vague["NSCameraUsageDescription"] = "Kamera gerekir."
    with path.open("wb") as handle:
        plistlib.dump(vague, handle)
    assert any("NSCameraUsageDescription" in error for error in validate(path))

print("Privacy plist tests passed")
