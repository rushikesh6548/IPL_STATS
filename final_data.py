import pandas as pd
from datetime import datetime
from sqlalchemy import create_engine


# Load the Excel file
file_path = "D:\IPL\IPL_STATS\cricbuzz_ball_by_ball_20250426_19.xlsx"  # Replace with your file path
df = pd.read_excel(file_path)
#df.columns  = ['BALL','COMMENTARY']
#print(df)
#df.rename({'Value 1':'BALL', 'Value 2':'COMMENTARY'}, axis='columns')
#print(df)

# Prepare new columns
bowler_list = []
batsman_list = []
event_list = []

for commentary in df['COMMENTARY']:
    if pd.isnull(commentary):
        bowler_list.append(None)
        batsman_list.append(None)
        event_list.append(None)
        continue

    try:
        if "to" in commentary:
            # Split based on 'to'
            parts = commentary.split('to', 1)
            bowler = parts[0].strip()

            rest = parts[1].strip()
            # Get batsman name (up to first comma)
            if ',' in rest:
                batsman, remaining = rest.split(',', 1)
                batsman = batsman.strip()
                remaining = remaining.strip()

                # If remaining starts with "out", set event to "Wicket"
                if remaining.lower().startswith("out"):
                    event = "WICKET"
                else:
                    # Otherwise event is the text until next comma (if any)
                    event = remaining.split(',', 1)[0].strip().upper() if ',' in remaining else remaining
            else:
                # No comma after batsman => No event available
                batsman = rest.strip()
                event = "Unknown"

            bowler_list.append(bowler)
            batsman_list.append(batsman)
            event_list.append(event)
        else:
            bowler_list.append(None)
            batsman_list.append(None)
            event_list.append(None)
    except Exception as e:
        print(f"Error processing commentary: {commentary}")
        bowler_list.append(None)
        batsman_list.append(None)
        event_list.append(None)

# Add new columns to dataframe
df['Bowler'] = bowler_list
df['Batsman'] = batsman_list
df['Event'] = event_list

# Save to a new Excel file
#df.to_excel(f"D:\IPL\IPL_STATS\output_with_extracted_data_{datetime.now().strftime('%Y%m%d_%H')}.xlsx", index=False)
print("✅ Extraction completed.")

#DATABASE CONNECTION INFORMATION
# SQL Server connection details
server = 'ITACHI007'  # or your server name
database = 'IPLINFO'  # Change this
table_name = 'BALLBYBALLCOMMENTARY'  # Same as the table you created
#username = 'your_username'  # Only if using SQL Authentication
#password = 'your_password'  # Only if using SQL Authentication


# For Windows Authentication
connection_string = f"mssql+pyodbc://{server}/{database}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"

# Create SQLAlchemy engine
engine = create_engine(connection_string)

# Insert the data
try:
    df.to_sql(table_name, con=engine, if_exists='append', index=False)
    print(f"✅ Data successfully appended to {table_name} table in {database} database.")
except Exception as e:
    print(f"❌ Failed to insert data: {e}")
