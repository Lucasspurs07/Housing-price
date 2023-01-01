{"metadata":{"kernelspec":{"language":"python","display_name":"Python 3","name":"python3"},"language_info":{"name":"python","version":"3.7.12","mimetype":"text/x-python","codemirror_mode":{"name":"ipython","version":3},"pygments_lexer":"ipython3","nbconvert_exporter":"python","file_extension":".py"}},"nbformat_minor":4,"nbformat":4,"cells":[{"cell_type":"code","source":"## install packages\n!python3 -m pip install -q \"mxnet<2.0.0\"\n!python3 -m pip install -q autogluon\n!python3 -m pip install -q -U graphviz\n!python3 -m pip install -q -U scikit-learn","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:56:08.354683Z","iopub.execute_input":"2022-07-26T10:56:08.355245Z","iopub.status.idle":"2022-07-26T10:57:53.267342Z","shell.execute_reply.started":"2022-07-26T10:56:08.355144Z","shell.execute_reply":"2022-07-26T10:57:53.266192Z"},"trusted":true},"execution_count":1,"outputs":[]},{"cell_type":"code","source":"from autogluon.tabular import TabularDataset, TabularPredictor\nimport os\nfor dirname, _, filenames in os.walk('/kaggle/input'):\n    for filename in filenames:\n        print(os.path.join(dirname, filename))\n#EDA和特征工程需要用到的库\nimport numpy as np\nimport pandas as pd\nimport matplotlib.pyplot as plt\nimport seaborn as sns\nimport scipy\nimport scipy.stats as stats\nfrom scipy.stats import norm,skew\nimport statsmodels.api as sm\nimport warnings\nimport math\n#建模需要用到的库\nimport shap\nfrom catboost import Pool\nfrom catboost import CatBoostRegressor\nfrom sklearn.model_selection import KFold, cross_val_score\nfrom sklearn.model_selection import train_test_split\nfrom sklearn.metrics import mean_absolute_error\n\n%matplotlib inline\nwarnings.simplefilter('ignore')\n\nplt.rcParams['font.sans-serif']=['SimHei'] #显示中文标签\nplt.rcParams['axes.unicode_minus']=False","metadata":{"_uuid":"8f2839f25d086af736a60e9eeb907d3b93b6e0e5","_cell_guid":"b1076dfc-b9ad-4769-8c92-a6c4dae69d19","execution":{"iopub.status.busy":"2022-07-26T10:58:34.248476Z","iopub.execute_input":"2022-07-26T10:58:34.249298Z","iopub.status.idle":"2022-07-26T10:58:34.265645Z","shell.execute_reply.started":"2022-07-26T10:58:34.249259Z","shell.execute_reply":"2022-07-26T10:58:34.264381Z"},"trusted":true},"execution_count":3,"outputs":[]},{"cell_type":"code","source":"train=TabularDataset('/kaggle/input/housing-price111/train.csv')\ntest=TabularDataset('/kaggle/input/housing-price111/test.csv')","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:37.122749Z","iopub.execute_input":"2022-07-26T10:58:37.123217Z","iopub.status.idle":"2022-07-26T10:58:38.760971Z","shell.execute_reply.started":"2022-07-26T10:58:37.123172Z","shell.execute_reply":"2022-07-26T10:58:38.759657Z"},"trusted":true},"execution_count":4,"outputs":[]},{"cell_type":"code","source":"#去除outlier\nsns.boxplot(train['房屋租金'])\nplt.title(\"Box Plot before outlier removing\")\nplt.show()\ndef drop_outliers(df, field_name):\n    df.drop(df[df[field_name]>7000].index, inplace=True)\n    df.drop(df[df[field_name]<45].index, inplace=True)\ndrop_outliers(train,'房屋租金')\nsns.boxplot(train['房屋租金'])\nplt.title(\"Box Plot after outlier removing\")\nplt.show()","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:38.762987Z","iopub.execute_input":"2022-07-26T10:58:38.763365Z","iopub.status.idle":"2022-07-26T10:58:39.418096Z","shell.execute_reply.started":"2022-07-26T10:58:38.763330Z","shell.execute_reply":"2022-07-26T10:58:39.417026Z"},"trusted":true},"execution_count":5,"outputs":[]},{"cell_type":"code","source":"#分离目标和特征\ntarget = train['房屋租金']\ntest_id = test['ID']\ntest = test.drop(['ID'],axis = 1)\ntrain_df = train.drop(['房屋租金','ID'], axis = 1)\n\n#合并训练集与测试集\ntrain_test = pd.concat([train_df,test], axis=0, sort=False)","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:41.646946Z","iopub.execute_input":"2022-07-26T10:58:41.647656Z","iopub.status.idle":"2022-07-26T10:58:41.725014Z","shell.execute_reply.started":"2022-07-26T10:58:41.647617Z","shell.execute_reply":"2022-07-26T10:58:41.724060Z"},"trusted":true},"execution_count":6,"outputs":[]},{"cell_type":"code","source":"#（1）去除掉无用的列 (缺失值太多加上相关系数太小)\nuseless = ['电力基础价格','没有停车位','上传日期'] \ntrain_test = train_test.drop(useless, axis = 1)\n#(2)\n#train_test['可带宠物'].fillna('negotiable',inplace=True)\n#train_test['最后翻新年份'].fillna(train_test['建成年份'],inplace=True)","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:46.503737Z","iopub.execute_input":"2022-07-26T10:58:46.504325Z","iopub.status.idle":"2022-07-26T10:58:46.556424Z","shell.execute_reply.started":"2022-07-26T10:58:46.504289Z","shell.execute_reply":"2022-07-26T10:58:46.555424Z"},"trusted":true},"execution_count":7,"outputs":[]},{"cell_type":"code","source":"#将bool值和object值转为字符并编码\ntrain_test['有阳台'] = train_test['有阳台'].astype('category')\ntrain_test['有厨房'] = train_test['有厨房'].astype('category')\ntrain_test['有地窖'] = train_test['有地窖'].astype('category')\ntrain_test['有电梯'] = train_test['有电梯'].astype('category')\ntrain_test['有花园'] = train_test['有花园'].astype('category')\ntrain_test['是新建筑'] = train_test['是新建筑'].astype('category')\ntrain_test['可带宠物'] = train_test['可带宠物'].astype('category')","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:48.677571Z","iopub.execute_input":"2022-07-26T10:58:48.677911Z","iopub.status.idle":"2022-07-26T10:58:48.733497Z","shell.execute_reply.started":"2022-07-26T10:58:48.677883Z","shell.execute_reply":"2022-07-26T10:58:48.732553Z"},"trusted":true},"execution_count":8,"outputs":[]},{"cell_type":"code","source":"#特征工程\ntrain_test['居住面积--2']=train_test['居住面积']**2\ntrain_test['每间房间平均面积']=train_test['居住面积']/(train_test['房间数量']+1)\ntrain_test['每平方米服务费']=train_test['服务费']/(train_test['居住面积']+1)\ntrain_test['每平方米供暖费用']=train_test['供暖费用']/(train_test['居住面积']+1)\nroom_features1 = ['有阳台','有厨房','有地窖','有电梯','有花园','是新建筑']\ntrain_test[\"roomFeatures1\"] = train_test[room_features1].sum(axis=1)\ntrain_test[\"不同建成年份平均服务费\"] = train_test.groupby(\"建成年份\")[\"服务费\"].transform(\"mean\")\n\ntrain_test[\"区域2平均建成年份\"] = train_test.groupby(\"区域2\")[\"建成年份\"].transform(\"median\")\ntrain_test[\"区域1平均建成年份\"] = train_test.groupby(\"区域1\")[\"建成年份\"].transform(\"median\")\ntrain_test[\"区域3平均建成年份\"] = train_test.groupby(\"区域3\")[\"建成年份\"].transform(\"median\")\ntrain_test[\"区域1平均服务费\"] = train_test.groupby(\"区域1\")[\"服务费\"].transform(\"mean\")\ntrain_test[\"区域2平均服务费\"] = train_test.groupby(\"区域2\")[\"服务费\"].transform(\"mean\")\ntrain_test[\"区域3平均服务费\"] =train_test.groupby(\"区域3\")[\"服务费\"].transform(\"mean\")\ntrain_test[\"区域1服务费标准差\"] = train_test.groupby(\"区域1\")[\"服务费\"].transform(\"std\")\ntrain_test[\"区域2服务费标准差\"] = train_test.groupby(\"区域2\")[\"服务费\"].transform(\"std\")\ntrain_test[\"区域3服务费标准差\"] = train_test.groupby(\"区域3\")[\"服务费\"].transform(\"std\")\ntrain_test[\"区域1价格趋势\"] = train_test.groupby(\"区域1\")[\"价格趋势\"].transform(\"mean\")\ntrain_test[\"区域2价格趋势\"] = train_test.groupby(\"区域2\")[\"价格趋势\"].transform(\"mean\")\ntrain_test[\"区域3价格趋势\"] = train_test.groupby(\"区域3\")[\"价格趋势\"].transform(\"mean\")\ntrain_test[\"区域1价格趋势标准差\"] = train_test.groupby(\"区域1\")[\"价格趋势\"].transform(\"std\")\ntrain_test[\"区域2价格趋势标准差\"] = train_test.groupby(\"区域2\")[\"价格趋势\"].transform(\"std\")\ntrain_test[\"区域3价格趋势标准差\"] = train_test.groupby(\"区域3\")[\"价格趋势\"].transform(\"std\")\ntrain_test[\"区域1居住面积\"] = train_test.groupby(\"区域1\")[\"居住面积\"].transform(\"mean\")\ntrain_test[\"区域2居住面积\"] = train_test.groupby(\"区域2\")[\"居住面积\"].transform(\"mean\")\ntrain_test[\"区域3居住面积\"] = train_test.groupby(\"区域3\")[\"居住面积\"].transform(\"mean\")\ntrain_test[\"区域1居住面积标准差\"] = train_test.groupby(\"区域1\")[\"居住面积\"].transform(\"std\")\ntrain_test[\"区域2居住面积标准差\"] = train_test.groupby(\"区域2\")[\"居住面积\"].transform(\"std\")\ntrain_test[\"区域3居住面积标准差\"] = train_test.groupby(\"区域3\")[\"居住面积\"].transform(\"std\")\ntrain_test[\"区域1供暖费用\"] = train_test.groupby(\"区域1\")[\"供暖费用\"].transform(\"mean\")\ntrain_test[\"区域2供暖费用\"] = train_test.groupby(\"区域2\")[\"供暖费用\"].transform(\"mean\")\ntrain_test[\"区域3供暖费用\"] = train_test.groupby(\"区域3\")[\"供暖费用\"].transform(\"mean\")\ntrain_test[\"区域1供暖费用标准差\"] = train_test.groupby(\"区域1\")[\"供暖费用\"].transform(\"std\")\ntrain_test[\"区域2供暖费用标准差\"] = train_test.groupby(\"区域2\")[\"供暖费用\"].transform(\"std\")\ntrain_test[\"区域3供暖费用标准差\"] = train_test.groupby(\"区域3\")[\"供暖费用\"].transform(\"std\")\ntrain_test[\"街道平均建成年份\"] = train_test.groupby(\"街道\")[\"建成年份\"].transform(\"median\")\ntrain_test[\"街道平均服务费\"] = train_test.groupby(\"街道\")[\"服务费\"].transform(\"mean\")\ntrain_test[\"街道价格趋势\"] = train_test.groupby(\"街道\")[\"价格趋势\"].transform(\"mean\")\ntrain_test[\"街道居住面积\"] = train_test.groupby(\"街道\")[\"居住面积\"].transform(\"mean\")\ntrain_test[\"街道供暖费用\"] = train_test.groupby(\"街道\")[\"供暖费用\"].transform(\"mean\")\ntrain_test[\"街道服务费标准差\"] = train_test.groupby(\"街道\")[\"服务费\"].transform(\"std\")\ntrain_test[\"街道供暖费用标准差\"] = train_test.groupby(\"街道\")[\"供暖费用\"].transform(\"std\")\ntrain_test[\"街道居住面积标准差\"] = train_test.groupby(\"街道\")[\"居住面积\"].transform(\"std\")\ntrain_test[\"街道价格趋势标准差\"] = train_test.groupby(\"街道\")[\"价格趋势\"].transform(\"std\")\n\n\n#查看频率\ntemp = train_test['房屋状况'].value_counts().to_dict()\ntrain_test['房屋状况_counts'] = train_test['房屋状况'].map(temp)\ntemp = train_test['内饰质量'].value_counts().to_dict()\ntrain_test['内饰质量_counts'] = train_test['内饰质量'].map(temp)\ntemp = train_test['加热类型'].value_counts().to_dict()\ntrain_test['加热类型_counts'] = train_test['加热类型'].map(temp)\ntemp = train_test['房间数量'].value_counts().to_dict()\ntrain_test['房间数量_counts'] = train_test['房间数量'].map(temp)\ntemp = train_test['所处楼层'].value_counts().to_dict()\ntrain_test['所处楼层_counts'] = train_test['所处楼层'].map(temp)\ntemp = train_test['建筑楼层'].value_counts().to_dict()\ntrain_test['建筑楼层_counts'] = train_test['建筑楼层'].map(temp)\ntemp = train_test['建成年份'].value_counts().to_dict()\ntrain_test['建成年份_counts'] = train_test['建成年份'].map(temp)\ntemp = train_test['上传图片数'].value_counts().to_dict()\ntrain_test['上传图片数_counts'] = train_test['上传图片数'].map(temp)\ntemp = train_test['房屋类型'].value_counts().to_dict()\ntrain_test['房屋类型_counts'] = train_test['房屋类型'].map(temp)\ntemp = train_test['最后翻新年份'].value_counts().to_dict()\ntrain_test['最后翻新年份_counts'] = train_test['最后翻新年份'].map(temp)\n\n#对分类特征进行编码\ntrain_test_dummy = pd.get_dummies(train_test)\n#找出偏度较大的数值特征\nnumeric_features = ['服务费','供暖费用','居住面积','价格趋势']\nskewed_features = train_test_dummy[numeric_features].apply(lambda x: skew(x)).sort_values(ascending=False)\nhigh_skew = skewed_features[skewed_features > 0.5]\nskew_index = high_skew.index\n#用log变换对偏度大的数值特征做变换\nfor i in skew_index:\n    train_test_dummy[i] = np.log1p(train_test_dummy[i])","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:51.341844Z","iopub.execute_input":"2022-07-26T10:58:51.342223Z","iopub.status.idle":"2022-07-26T10:58:52.808590Z","shell.execute_reply.started":"2022-07-26T10:58:51.342193Z","shell.execute_reply":"2022-07-26T10:58:52.807453Z"},"trusted":true},"execution_count":9,"outputs":[]},{"cell_type":"code","source":"#经过对数转换后的房屋租金\n\ntarget_log = np.log1p(target)\n\nfig, ax = plt.subplots(1,2, figsize= (15,5))\nfig.suptitle(\"qq-plot & distribution SalePrice \", fontsize= 15)\n\nsm.qqplot(target_log, stats.t, distargs=(4,),fit=True, line=\"45\", ax = ax[0])\nsns.distplot(target_log, kde = True, hist=True, fit = norm, ax = ax[1])\nplt.show()","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:55.110608Z","iopub.execute_input":"2022-07-26T10:58:55.110963Z","iopub.status.idle":"2022-07-26T10:58:59.823970Z","shell.execute_reply.started":"2022-07-26T10:58:55.110934Z","shell.execute_reply":"2022-07-26T10:58:59.823073Z"},"trusted":true},"execution_count":10,"outputs":[]},{"cell_type":"code","source":"#训练集和测试集分离\n\ntrain = train_test_dummy[0:199839]\ntest = train_test_dummy[199839:]\ntest['ID'] = test_id","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:59.825905Z","iopub.execute_input":"2022-07-26T10:58:59.826849Z","iopub.status.idle":"2022-07-26T10:58:59.834162Z","shell.execute_reply.started":"2022-07-26T10:58:59.826811Z","shell.execute_reply":"2022-07-26T10:58:59.833249Z"},"trusted":true},"execution_count":11,"outputs":[]},{"cell_type":"code","source":"train=pd.concat([train,target_log],axis=1)","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:58:59.835378Z","iopub.execute_input":"2022-07-26T10:58:59.835861Z","iopub.status.idle":"2022-07-26T10:59:00.024108Z","shell.execute_reply.started":"2022-07-26T10:58:59.835823Z","shell.execute_reply":"2022-07-26T10:59:00.023115Z"},"trusted":true},"execution_count":12,"outputs":[]},{"cell_type":"code","source":"train.info(max_cols=150)","metadata":{"execution":{"iopub.status.busy":"2022-07-26T10:59:00.425771Z","iopub.execute_input":"2022-07-26T10:59:00.426477Z","iopub.status.idle":"2022-07-26T10:59:00.476404Z","shell.execute_reply.started":"2022-07-26T10:59:00.426442Z","shell.execute_reply":"2022-07-26T10:59:00.475275Z"},"trusted":true},"execution_count":13,"outputs":[]},{"cell_type":"code","source":"\nmetric = 'mae'  \nlabel ='房屋租金'\npredictor = TabularPredictor(label, eval_metric=metric).fit(train,excluded_model_types = ['KNN'],presets='best_quality')","metadata":{"execution":{"iopub.status.busy":"2022-07-25T01:07:47.310759Z","iopub.execute_input":"2022-07-25T01:07:47.311365Z","iopub.status.idle":"2022-07-25T01:08:04.986316Z","shell.execute_reply.started":"2022-07-25T01:07:47.311324Z","shell.execute_reply":"2022-07-25T01:08:04.984306Z"},"trusted":true},"execution_count":null,"outputs":[]},{"cell_type":"code","source":"pred = predictor.predict(test.drop(columns=['ID']))\ntest['房屋租金'] = pred","metadata":{"execution":{"iopub.status.busy":"2022-07-17T11:09:23.117442Z","iopub.execute_input":"2022-07-17T11:09:23.117706Z","iopub.status.idle":"2022-07-17T11:25:35.813396Z","shell.execute_reply.started":"2022-07-17T11:09:23.117680Z","shell.execute_reply":"2022-07-17T11:25:35.811181Z"},"trusted":true},"execution_count":null,"outputs":[]},{"cell_type":"code","source":"test.info()","metadata":{"execution":{"iopub.status.busy":"2022-07-17T11:26:02.695846Z","iopub.execute_input":"2022-07-17T11:26:02.696522Z","iopub.status.idle":"2022-07-17T11:26:02.727221Z","shell.execute_reply.started":"2022-07-17T11:26:02.696489Z","shell.execute_reply":"2022-07-17T11:26:02.726038Z"},"trusted":true},"execution_count":null,"outputs":[]},{"cell_type":"code","source":"test['房屋租金']=np.exp(test['房屋租金'])","metadata":{"execution":{"iopub.status.busy":"2022-07-17T11:26:06.856724Z","iopub.execute_input":"2022-07-17T11:26:06.857112Z","iopub.status.idle":"2022-07-17T11:26:06.887647Z","shell.execute_reply.started":"2022-07-17T11:26:06.857082Z","shell.execute_reply":"2022-07-17T11:26:06.886259Z"},"trusted":true},"execution_count":null,"outputs":[]},{"cell_type":"code","source":"test[['ID','房屋租金']].to_csv('/kaggle/working/result.csv', index=False)","metadata":{"execution":{"iopub.status.busy":"2022-07-17T11:26:11.877579Z","iopub.execute_input":"2022-07-17T11:26:11.877987Z","iopub.status.idle":"2022-07-17T11:26:12.005925Z","shell.execute_reply.started":"2022-07-17T11:26:11.877955Z","shell.execute_reply":"2022-07-17T11:26:12.004818Z"},"trusted":true},"execution_count":null,"outputs":[]},{"cell_type":"code","source":"","metadata":{},"execution_count":null,"outputs":[]}]}