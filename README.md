# Peek Senior Data Analyst Case Study 

Analysis for TheLook, an ecommerce marketplace, written as its first Senior Data Analyst.

Dataset: `bigquery-public-data.thelook_ecommerce` (BigQuery).

## 1. How to run queries files
**Steps**
1. Download the files in `sql/`.
2. Open each file in the BigQuery console and run it **as a whole**. Do not run the statements one by one: the scripts create temporary tables (for example `completed_order_items`), which only exist while the script is running, and BigQuery returns the error "Use of CREATE TEMPORARY TABLE requires a script or session" otherwise.
3. Each script is self-contained: parameters, the base model `completed_order_items` (single source of truth for that script), then the final queries. Each final query returns its own result tab.
4. Run order does not matter, since no script depends on another.

**Tables created by `business_KPI.sql`**
 
| Table | Task | One row = | Main columns | Used for |
|---|---|---|---|---|
| `completed_order_items` | A2 | One completed order item | `order_item_id`, `order_id`, `user_id`, `product_id`, `ordered_at`, `order_date`, `order_month`, `revenue`, `cost`, `gross_profit`, `num_of_item`, `brand`, `traffic_source` | Single source of truth: every other table reads it |
| `business_health` | A3 | One complete month | `month`, `revenue`, `gross_profit`, `orders`, `units`, `gross_margin_pct`, `aov`, `mom`, `session_conversion_rate` | Visual 1 |
| `user_months` | B (helper) | One customer in one month in which they ordered | `user_id`, `month`, `first_month`, `next_order_date`, `revenue`, `num_orders` (item count, not used later) | Input of B1 and B2 |
| `new_vs_returning` | B1 | One month | `month`, `active_customers`, `new_customers`, `returning_customers`, `revenue_new`, `revenue_returning`, `pct_revenue_from_returning` | Visual 2 |
| `churn_summary` | B2 | One month | `month`, `active_customers`, `window_closes_on`, `is_mature`, `churned_customers_90d`, `churn_rate_90d_pct` (empty for immature months), `revenue_new`, `revenue_returning` | Visual 2 (revenue bars and churn line) |

## Definitions
 
| Term | Definition |
|---|---|
| **Revenue** | `sale_price` of completed items, dated by **order date** (not delivery date) |
| **Gross profit / margin** | `sale_price` minus product `cost`; margin = gross profit / revenue |
| **AOV** | Revenue / completed orders |
| **Active customer (month M)** | At least one completed order in month M |
| **New customer (month M)** | Month M is the month of the customer's first completed order in the data (see the limitation on the start date) |
| **Returning customer (month M)** | Active in M, with a first completed order in an earlier month |
| **90-day churn (month M)** | Active in M, and the customer's next completed order is missing or later than the end of M plus 90 days (the window starts the day after the end of M). Churn rate = churned / active |
| **Session conversion rate** | Purchase events / department events in the month, based on the month of the event (see limitations) |
| **Return rate (brand)** | Returned items / (completed + returned items); cancelled, processing and shipped items are excluded because their outcome is not known. |

## Assumptions and date ranges
 
- **`As-of date`:** It is the smallest of the last order date, the last event date and today, so it is never in the future. It is a parameter so results can be reproduced or backtested.
- **Data window:** from 1 Jan 2019 to the last **complete** month before today, which is **Sep 2026** on the as-of date. The window is built with a month list: a month is kept only if it starts on or after `start_date`, ends on or before `end_date` and starts before the first day of the current month. The current month is therefore excluded, so a partial month never looks like a drop. The dashboard shows the last 24 months, Oct 2024 to Oct 2026.
- **90-day churn is published only for mature months:** a month is mature if its 90-day window closed by the as-of date. On the as-of date that means months up to Jun 2026. Immature months stay in the table with no rate, instead of showing an artificially low churn.
- **Revenue by order date, `Complete` items only.** Returned items are therefore not in revenue; returns are analysed separately.
- **Future-dated orders are excluded** because only complete past months are kept.
- **No filter on price or cost** in the base model; the data quality checks found no invalid values.

## Limitations Of the 90-day churn definition
1. **One fixed window for everyone.** 90 days is arbitrary; categories with long repurchase cycles look "churned" while still healthy. *Refinement:* set the window from the observed distribution of time between orders (for example the 80th to 90th percentile), per category or segment.
2. **Binary and reversible.** "Churned" customers can come back, so this measures lapsing, not permanent loss. *Refinement:* track reactivation and call the metric "lapsed".

## Dashboard link 
https://datastudio.google.com/s/ps4gAaZq03E

## AI Workflow idea 
**Workflow idea:** Build an AI-powered workflow that analyzes user comments and automatically generates a monthly performance summary for each brand. The goal is to help brands understand customer sentiment, identify recurring feedback and spot areas for improvement without manually reviewing thousands of comments.

- **Data inputs:** The model would analyze user comments, reviews and feedback associated with each brand, along with relevant metadata such as dates, product categories and sentiment labels. It could identify recurring themes, positive and negative feedback, and changes in customer sentiment over time. Only data relevant to the brand’s analysis would be included. Personal information, sensitive data and comments belonging to other brands would be excluded.

- **Key prompt / system prompt:** *“Analyze the user feedback associated with this brand for the selected month. Summarize the main positive and negative themes, identify recurring customer concerns, highlight changes compared with the previous month, and suggest actionable areas for improvement. Support every insight with evidence from the comments and available metrics. Do not invent explanations, infer unsupported causes, or make claims that cannot be verified from the available data. If the evidence is insufficient, explicitly state this limitation.”*

- **Guardrails:** The workflow would use brand-specific data access permissions to prevent data leakage between partners. Quantitative metrics, such as comment volume and sentiment percentages, would be calculated from validated data. The AI would only produce explanations supported by actual user feedback, flag insufficient data and distinguish observed trends from hypotheses. Each summary would include traceable evidence or representative comments where appropriate, with personal information removed.
  
- **Human in the loop:** Before being shared with a brand, the monthly summary would be reviewed by a team member to validate the main insights, check for misleading interpretations and ensure that recommendations are relevant. Human reviewers could correct the output and flag recurring errors to improve the workflow over time.

- **Success metrics:**
    - **Adoption:** Percentage of brands and internal team members using the summaries regularly.
    - **Output quality:** Accuracy of extracted themes, consistency of sentiment analysis and percentage of insights supported by evidence.
    - **Efficiency:** Reduction in the time spent manually analyzing comments and preparing monthly reports.
    - **Business impact:** Whether brands use the insights to adjust their products, campaigns or customer experience, and whether they report greater satisfaction with the service.

- **Shutdown criteria:** The workflow would be paused if it repeatedly generates unsupported insights, produces materially incorrect metrics, exposes data across brands or fails to save meaningful time compared with manual reporting. It would only be relaunched once the underlying issues had been addressed and the system had passed validation tests.

## AI use in the analysis
I use an LLM assistant (Claude) to help me debug certain parts of my queries. I also use it to organize and clean up my code after analysis, so that it’s as easy as possible for an outsider to understand, and to ensure I’m following best practices.
I always make sure that Claude doesn't change the logic of my query, and I run everything again before submitting.

**Example prompt:** *"Based on these queries, analyze each one and let me know when it's possible to optimize the code or if any best practices for presentation are missing."*
 
