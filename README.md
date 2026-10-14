# Kenya Mobile Money: 10 Questions, Answered Twice

Analysis of a year (2024) of synthetic Kenyan mobile-money transactions: 6,000 transactions, 800 customers, 20 counties, across M-Pesa, Airtel Money, T-Kash and Equitel.

Every question is solved **twice**, once in pandas and once in SQL. The notebook loads the data into an in-memory SQLite database, runs each query from `sql/questions.sql`, and **asserts that both answers match**. If they disagree, the notebook fails.

## Key findings

| # | Question | Answer |
|---|---|---|
| 1 | Fastest month-over-month fee growth | **May 2024, +11.2%**, but revenue is flat overall (KES 31k–37k per month) |
| 2 | Busiest time block | **Wednesday 09:00–10:00** |
| 4 | Days above 1.5× the 7-day rolling average | **4 days** |
| 5 | RFM Champions | **121 customers**, averaging KES 333k each |
| 6 | Least reliable channel × type | **T-Kash Buy Goods (Till), 15% failed or reversed** (M-Pesa ≈ 6%) |
| 7 | Fee structure | Highest effective rate on **KES 1,001–5,000 (0.91%)**, lowest on 20,000+ (0.25%) |
| 9 | Customer growth | 365 customers joined in January, and **new sign-ups fell to ~0 by July** |
| 10 | County concentration | **12 of 20 counties** make up 80% of value, so no strong Pareto effect |

**Business takeaways:** the platform keeps its customers but stopped acquiring new ones mid-year. Smaller channels need reliability fixes. The fee structure favours large senders. Value is spread across the country, not concentrated in a few counties.

## Project layout

```
data/kenya_mobile_money_transactions.csv   the dataset (from LuxDevHQ)
notebook/mobile_money_analysis.ipynb       pandas solutions, charts, SQL cross-checks, insights
sql/questions.sql                          one SQL query per question (SQLite dialect)
```

## Run it

```bash
pip install -r requirements.txt
jupyter notebook notebook/mobile_money_analysis.ipynb
```

The SQL file uses standard window functions (`LAG`, `RANK`, `NTILE`, `SUM() OVER`) and runs on SQLite 3.25+. It ports to PostgreSQL with small date-function changes.

## Data

Synthetic dataset from the [LuxDevHQ Data repo](https://github.com/LuxDevHQ/Data/tree/main/projects/kenya-mobile-money). No real people or phone numbers.

## Author

Jesse Ngugi · [github.com/ngugiauraa](https://github.com/ngugiauraa)
