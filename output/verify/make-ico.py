import io
import struct
import os

assets = r"D:\Window Word\src\WordDrawer.App\Assets"
sizes = [16, 24, 32, 48, 64, 128, 256]

blobs = []
for size in sizes:
    with open(os.path.join(assets, f"logo-{size}.png"), "rb") as fh:
        blobs.append((size, fh.read()))

header = struct.pack("<HHH", 0, 1, len(blobs))
offset = len(header) + 16 * len(blobs)
entries = b""
data = b""
for size, blob in blobs:
    dim = 0 if size >= 256 else size
    entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(blob), offset)
    offset += len(blob)
    data += blob

ico_path = os.path.join(assets, "worddrawer.ico")
with open(ico_path, "wb") as fh:
    fh.write(header + entries + data)

print("ico written:", ico_path, os.path.getsize(ico_path), "bytes,", len(blobs), "sizes")
