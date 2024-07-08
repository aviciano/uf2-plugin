import json

with open("./uf2families.json") as fd:
    uf2 = json.load(fd)
    sorted_families = sorted(uf2, key=lambda x: x["id"])
    for item in sorted_families:
        f_id = item["id"]
        name = item["short_name"]
        desc = item["description"]
        arch = f"\"{item['arch']}\"" if "arch" in item else "NULL"
        cpu = f"\"{item['cpu']}\"" if "cpu" in item else "NULL"
        bits = item['bits'] if "bits" in item else -1
        print(f"{{ {f_id}, \"{name}\", \"{desc}\", {arch}, {cpu}, {bits} }},")
