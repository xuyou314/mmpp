import pandas as pd
import datetime
import re
import matplotlib.pyplot as plt
pattern= re.compile(r'(\d+)\/(\d+)\/(\d+) (\d+):(\d+)')
def rowmap(row):
    mch = pattern.match(row['time'])
    params = list(map(int, mch.groups()))
    min = int(row['time'][-2:])
    dt = datetime.datetime(*params)
    if min > 30:
        dt = dt - datetime.timedelta(minutes=min - 30)
    if min < 30 and min > 0:
        dt = dt - datetime.timedelta(minutes=min)
    dt_str = dt.strftime("%Y-%m-%d %H:%M")
    row['time']=dt_str
    return row
# def loop_process():
#     for i in range(len(data)):
#         mch=pattern.match(data['time'][i])
#         params=list(map(int,mch.groups()))
#         min=int(data['time'][i][-2:])
#         dt = datetime.datetime(*params)
#         if min>30:
#             dt=dt-datetime.timedelta(minutes=min-30)
#         if min<30 and min>0:
#             dt=dt-datetime.timedelta(minutes=min)
#         dt_str=dt.strftime("%Y-%m-%d %H:%M")
#         data['time'][i]=dt_str
def vis():
    res=pd.read_csv("precessed_data.csv")
    plt.plot(res['count'])
    plt.show()
if __name__=='__main__':
    # data = pd.read_csv("../demo_data.csv")
    # data_res=data.apply(rowmap,axis=1)
    # res=data_res.groupby(by="time").sum()
    # #res.to_csv("precessed_data.csv")
    vis()