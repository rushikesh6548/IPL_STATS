from bs4 import BeautifulSoup
import re

# Load HTML from file
file_path = "/content/zdfasf.txt"  # Change this if needed
with open(file_path, "r", encoding="utf-8") as file:
    html_content = file.read()

# Parse HTML using lxml parser
soup = BeautifulSoup(html_content, "lxml")

# Find all divs where id starts with 'comm_'
commentary_blocks = soup.find_all("div", id=re.compile(r"^comm_"))

# Extract relevant information
ball_data = []
for block in commentary_blocks:
    over_element = block.find("div", class_="cb-mat-mnu-wrp cb-ovr-num ng-binding ng-scope")
    commentary_element = block.find("p", class_="cb-com-ln ng-binding ng-scope cb-col cb-col-90")

    if over_element and commentary_element:
        over = over_element.text.strip()
        commentary = commentary_element.text.strip()
        ball_data.append((over, commentary))

# Print first 10 records as a sample
for record in ball_data:
    print(record)
