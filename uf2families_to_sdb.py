import json

with open("./uf2families.json") as fd:
    uf2 = json.load(fd)
    result = [
            (
                item["id"],
                item["short_name"],
                item["description"],
                item["arch"] if "arch" in item else "",
                item["bits"] if "bits" in item else "",
                item["cpu"] if "cpu" in item else ""
            )
            for item in uf2
    ]
    for item in result:
        print(f"{item[0]}='{item[1]}','{item[2]}',{item[3]},{item[4]},{item[5]}")
