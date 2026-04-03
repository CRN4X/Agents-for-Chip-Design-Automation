import pandas as pd

df = pd.read_json("input.jsonl", lines=True)
df.to_parquet("data.parquet")   # 🔥 best format

print(df.__len__())
print(df.head(5))