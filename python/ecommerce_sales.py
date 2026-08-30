import pandas as pd
from sqlalchemy import create_engine


#                      mysql+pymysql://user:password@localhost/olist_ecommerce
engine = create_engine("mysql+pymysql://root:Root%40123@localhost/olist_ecommerce")
df = pd.read_sql("SELECT * FROM vw_delivery_satisfaction", engine)

df.info()
df.isnull().sum()


"""
OUTPUT
<class 'pandas.DataFrame'>
RangeIndex: 96146 entries, 0 to 96145
Data columns (total 6 columns):
 #   Column               Non-Null Count  Dtype  
---  ------               --------------  -----  
 0   order_id             96146 non-null  str    
 1   customer_state       96146 non-null  str    
 2   seller_state         96146 non-null  str    
 3   delivery_delay_days  96138 non-null  float64
 4   review_score         96146 non-null  int64  
 5   order_value          96146 non-null  float64
dtypes: float64(2), int64(1), str(3)
memory usage: 4.4 MB
"""


# Calculate correlation between delivery_delay_days and  review_score 
from scipy import stats

# pearson correlation
corr, p_value = stats.pearsonr(df['delivery_delay_days'].dropna(), df.loc[df['delivery_delay_days'].notnull(), 'review_score'])
print(f"Correlation: {corr:.3f}, p-value: {p_value}")
"""
OUTPUT
Correlation: -0.261, p-value:≈0.0
"""



# use Spearman correlation as review_score is ordinal
corr_s, p_s = stats.spearmanr(df['delivery_delay_days'].dropna(), df.loc[df['delivery_delay_days'].notnull(), 'review_score'])
print(f"Spearman correlation: {corr_s:.3f}, p-value: {p_s}")
"""
OUTPUT
Spearman correlation: -0.171, p-value: ≈0.0
"""
# A negative correlation with p < 0.05 confirms: delay and satisfaction are statistically linked



# to identify revenue at risk due to low reviews we will calculate order values of such orders
risk_segment = df[(df['delivery_delay_days'] >= 4) & (df['review_score'] <= 2)]
revenue_at_risk = risk_segment['order_value'].sum()
pct_of_total = revenue_at_risk / df['order_value'].sum() * 100

print(f"Revenue at risk: R${revenue_at_risk:,.2f} ({pct_of_total:.1f}% of total revenue)")
"""
OUTPUT
Revenue at risk: R$628,320.76 (4.1% of total revenue)
"""



# Identify worst-performing sellers/states
seller_perf = df.groupby('seller_state').agg(
        avg_delay=('delivery_delay_days', 'mean'),
        avg_review=('review_score', 'mean'),
        order_count=('order_id', 'count'),
        total_value=('order_value', 'sum')
    ).sort_values('avg_delay', ascending=False)

print(seller_perf.head(10))
"""
OUTPUT
              avg_delay  avg_review  order_count  total_value
seller_state                                                 
AM             9.000000    2.333333            3      1258.80
SP           -11.180126    4.124704        68025   9857922.75
PA           -11.375000    4.500000            8      1393.11
MA           -11.492188    4.020833          384     47329.68
RJ           -12.494990    4.219227         4192    903138.32
BA           -12.663620    4.191956          547    293688.49
CE           -13.151163    4.302326           86     23578.37
DF           -13.272615    4.095415          807    112805.72
ES           -13.356209    4.147059          306     58227.80
MG           -13.459262    4.226378         7673   1172332.02

"""
# seller_states like AM, PA cannot not be considered low performing as they have negligile order count
# Also Most of orders have -ve avg delay. this means they are not worst states but least early states