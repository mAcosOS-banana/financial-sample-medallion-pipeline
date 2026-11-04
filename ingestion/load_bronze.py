from sqlalchemy import Engine, create_engine
from dotenv import load_dotenv
import os
import polars as pl
from pathlib import Path
from utils import normalizar_nome
load_dotenv()

engine : Engine = create_engine(os.getenv('POSTGRES_URL'))

RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"


if __name__ == "__main__":
   manufacturing_data = [
      RAW_DIR / "Base_de_dados_2013_2014_-_Manufacturing.xlsx",
      RAW_DIR / "Base_de_dados_2015_2016_-_Manufacturing.xlsx",
   ]
   sales_data = [
      RAW_DIR / "Base_de_dados_2013_2014_-_Sales.xlsx",
      RAW_DIR / "Base_de_dados_2015_2016_-_Sales.xlsx",
   ]

   for d in sales_data:
      df : pl.DataFrame = pl.read_excel(
         d,
         engine="calamine"
      )


      df = df.rename(
         {col: normalizar_nome(col) for col in df.columns}
      )
      try:
         df = df.with_columns(
            pl.col("country,product")
            .str.split_exact(",", 1)
            .struct.rename_fields(["country", "product"])
            .alias("split")
         ).unnest("split").drop("country,product")
      except Exception:
         print("ok")
      
      df.write_database(
         table_name="raw.sales_raw",
         engine="sqlalchemy",
         if_table_exists="append",
         connection=engine.connect()
      )