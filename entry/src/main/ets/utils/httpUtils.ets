import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';

//测试环境服务器
const baseUrl = 'http://10.18.18.230:8081/api'

const request = {
  post(url, params) {
    let bhmToken = '';
    if (url.includes('/login')) {
      bhmToken = '';
    } else {
      bhmToken = AppStorage.Get('bhm-token');
    }
    return new Promise((resolve, reject) => {
      let httpRequest = http.createHttp();
      let promise = httpRequest.request(baseUrl + url, {
        method: http.RequestMethod.POST,
        connectTimeout: 600000,
        readTimeout: 1000000,
        header: {
          'Content-Type': 'application/json',
          'bhm-token': bhmToken
        },
        expectDataType: http.HttpDataType.OBJECT,
        extraData: params
      });
      promise.then((data) => {
        if (data.responseCode == 200) {
          resolve(data.result)
        } else {
          promptAction.showToast({
            message: '系统异常，请稍微重试',
            duration: 2000,
          });
          reject(data.responseCode)
        }
      }).catch((err) => {
        reject(err)
        console.info('error:' + JSON.stringify(err));
      });
    })
  },
  get(url) {
    let bhmToken = '';
    if (url.includes('/login')) {
      bhmToken = '';
    } else {
      bhmToken = AppStorage.Get('bhm-token');
    }
    return new Promise((resolve, reject) => {
      let httpRequest = http.createHttp();
      let promise = httpRequest.request(baseUrl + url, {
        method: http.RequestMethod.GET,
        connectTimeout: 60000,
        readTimeout: 10000,
        header: {
          'Content-Type': 'application/json',
          'bhm-token': bhmToken
        },
        expectDataType: http.HttpDataType.OBJECT, // 可选，指定返回数据的类型
      });
      promise.then((data) => {
        if (data.responseCode == 200) {
          resolve(data.result)

        } else {
          promptAction.showToast({
            message: '系统异常，请稍微重试',
            duration: 2000,
          });
          reject(data.responseCode)
        }
      }).catch((err) => {
        reject(err)
        console.info('error:' + JSON.stringify(err));
      });
    })
  },
}

export default request
