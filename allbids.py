# coding:utf-8
__author__ = 'chenke'

"""
查询采购与招标网中风力发电机组的招标信息
获取验证码的地址并下载，输入验证码后登录
以关键字“风电”进行搜索，获取标题及地址
筛选标题去除相关条目后进一步搜索公告内容
显示最终结果的地址及标题并打开相应的网页
date: 2019/5/12
version: Python3.6
"""

from requests_html import HTMLSession
import os
import sys
import time
import webbrowser


class Bidding:
    def __init__(self, url, page):
        self.url = url
        self.loginurl = self.url + '/cblcn/member.login/login'
        self.yzmurl = self.url + '/cblcn/member.login/captcha'
        self.loginchkurl = self.url + '/cblcn/member.login/logincheck'
        self.page = page
        self.key_title1 = '风电'
        self.key_title2 = '风力'
        self.key_content = '风力发电机组'
        self.exp_list = [
            '询价', '施工', '维修', '维护', '运维', '改造', '接地', '海缆',
            '改建', '中标', '塔筒', '塔架', '基础', '法兰', '锚栓', '压站',
            '主轴', '主变', '箱变', '勘察', '设计', '滤芯', '螺栓', '电气',
            '线路', '道路', '监理', '备件', '吊装', '可研', '润滑', '配电',
            '装置', '检测', '检修', '监测', '监督', '测试', '测评', '试验',
            '变更', '更换', '技改', '验收', '安装', '分包', '电缆', '光缆',
            '材料', '箱式', '框架', '造价', '通信', '编码', '定检', '叶片',
            '倒运', '消防', '开关', '主体', '集控', '诊断', '齿轮', '柴油',
            '部件', '电池', '风扇', '充电', '故障', '消缺', '外委', '水土',
            '电容', '稳控', '变桨', '滑环', '打捆', '咨询', '测风', '电压',
            '电源', '电阻', '电梯', '模块', '网关', '数据', '驱动', '配件',
            '刹车', '升降', '防尘', '评估', '档案', '监控', '偏航', '标识',
            '土建', '振动', '仿真', '通讯', '液压', '雷电', '租赁', '端子',
            '紫铜', '蓄能', '加热', '控制', '接口', '导流', '变频', '工控',
            '继电器', '风速仪', '熔断器', '交换机', '集电环', '联轴器',
            '变压器', '变流器', '可行性', '启动', '滤网', '补偿', '二次',
            'GIS', 'SVG', '加密', '除湿', '寻甸', '元谋', '风向', '运输']  # 电机
        self.sel_title = 'tbody tr td a'
        self.sel_content = 'div.xq_nr'
        self.sel_pubdate = 'div.xiab_1 > span'
        self.session = HTMLSession()  # 获取session对象，可自动记录Cookies值
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.108 '
            'Safari/537.36',
            'referer': 'https://www.chinabidding.cn/',
            }
        self.data = {}
        self.t = time.time()
        self.stamp = str(round(self.t * 1000))  # 获取毫秒级时间戳
        self.now = time.strftime('%Y-%m-%d', time.localtime(self.t))  # 获取当前日

    def get_response(self, url):
        r = self.session.get(url, params=self.data, headers=self.headers)
        return r

    def chk_login(self):
        response = self.get_response(self.loginurl)  # 获取登录页面的验证码
        userid = response.html.find('div.deng_nr_1 > input',
                                    first=True).attrs['value']
        self.data = {
            't': self.stamp,
            'randomID': userid
        }
        yzmpic = self.get_response(self.yzmurl)  # 获取验证码图片并保存
        f = open('captcha.jpg', 'wb')
        f.write(yzmpic.content)
        f.close()

        os.system('start captcha.jpg')  # 显示验证码图片
        yzm = input('输入验证码：')
        logindata = {
            'name': '联合动力',
            'password': 'lhdlgdupc5765',
            'url': '',
            'yzm': yzm,
            'randomID': userid,
        }
        rep = self.session.post(self.loginchkurl, data=logindata,
                                headers=self.headers)
        # print(rep, rep.text)
        # response = self.session.post(self.loginurl, data=logindata,
        #                              headers=self.headers)
        # print(response.text)  # 登录成功自动跳转到首页
        if rep.text == '5':
            print('登录失败')
            return False
        else:
            print('登录成功')
            return True

    def get_result(self):
        start = time.time()
        if self.chk_login():  # 获取验证码、下载、输入并登录
            for i in range(1, self.page):
                searchurl = self.url + '/search/searchgj/zbcg'
                self.data = {
                    'areaid': '',
                    'keywords': '风电',
                    'time_start': self.now,
                    'time_end': self.now,
                    'page': i,
                    'search_type': 'CONTEXT',
                    'categoryid': '',
                    'rp': '30',
                    'table_type': '',
                    'b_date': 'week',
                }
                response = self.get_response(searchurl)
                item_list = response.html.find(self.sel_title)
                # print(item_list)
                for item in item_list:
                    try:
                        href = self.url + item.attrs['href']
                        title = item.attrs['title']
                    except Exception:
                        continue
                    # title = item.text
                    # print(title)
                    if self.chk_title(title):  # 筛选标题去除相关条目
                        if self.key_title1 in title or self.key_title2 \
                           in title:
                            response = self.get_response(href)
                            try:
                                content = response.html.find(
                                    self.sel_content, first=True).text
                                pubdate = response.html.find(
                                    self.sel_pubdate, first=True).text
                            except Exception:
                                continue
                            # print(content)
                            if self.key_content in content:
                                webbrowser.open(href)
                                print(href, pubdate, title)
                time.sleep(1)
        end = time.time() - start
        print('耗时：%.2f秒' % end)
        print(time.strftime("%H:%M:%S"))  # 当前时间

    def chk_title(self, title):
        for word in self.exp_list:
            if word in title:
                # print(word)
                return False
        # print(title)
        return True


if __name__ == "__main__":
    try:
        page = int(sys.argv[1])
    except Exception:
        print('用法: ' + sys.argv[0] + ' num 查询页数')
        sys.exit()
    chinabidding = Bidding('https://www.chinabidding.cn', page)
    chinabidding.get_result()
