test_dir = "test"


input_path = f"{test_dir}/psi.txt"
output_path = f"{test_dir}/psi_unique.txt"

with open(input_path, "r") as infile:
    lines = infile.readlines()



with open(input_path, "r") as infile:
    content = infile.read()

print(len(content))

print(lines)
# Split into lines manually

print(len(lines))

print(lines[-1])

seen = set()
unique_lines = []

for line in lines:
    # Skip empty lines (optional)
    if line and line not in seen:
        seen.add(line)
        unique_lines.append(line)

with open(output_path, "w") as outfile:
    for line in unique_lines:
        outfile.write(line + "\n")

print(f"Unique lines written: {len(unique_lines)}")

with open(input_path, "rb") as f:
    for i, line in enumerate(f, 1):
        if b"725c161da84d5d1" in line:
            print(f"Line {i}:")
            print("Length (bytes):", len(line))
            print("Hex dump:", line.hex(" "))
            print("Repr:", repr(line))
            break


# Full inspection: detect non-printable characters
with open(input_path, "rb") as f:
    raw = f.read()

for i, byte in enumerate(raw):
    if byte < 32 and byte not in (9, 10, 13):  # exclude tab, newline, carriage return
        print(f"Non-printable byte at position {i}: 0x{byte:02x}")

