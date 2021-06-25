# coding:utf-8
__author__ = 'chenke'

from requests_html import HTMLSession
import requests
import time
import datetime
import json
import os
# import webbrowser
import warnings
from colorama import init, Fore  # Back, Style


class Bids:
    def __init__(self):
        self.key_title = '风力发电'         # 标题关键字
        self.key_else = '风电'              # 标题关键字
        # self.key_else = '风电机组'          # 标题关键字
        self.key_content = '风力发电机组'   # 内容关键字
        self.exp_words = []
        self.sel_title = ''
        self.sel_content = ''
        self.sel_pubdate = ''
        self.vf = False
        self.session = HTMLSession()
        init(autoreset=True)  # 初始化并设置颜色自动恢复

    def get_result(self):
        response = self.get_response(self.url)
        if response:    # 获取对象不为空
            item_list = response.html.find(self.sel_title)
            # print(item_list)   # 标题列表
            for item in item_list:
                href = self.get_href(item)      # 获取URL
                title = self.get_title(item)    # 获取标题文本
                # title = item.text
                if self.chk_title(title):
                    if self.key_title in title or self.key_else in title:
                        # print(href, title)
                        response = self.get_response(href)
                        # print(response.html)
                        content = response.html.find(self.sel_content,
                                                     first=True).text
                        pubdate = response.html.find(self.sel_pubdate,
                                                     first=True).text
                        # print(content)
                        # print(pubdate)
                        pdate = self.get_date(pubdate)
                        # print(href, pdate, title)  # 查询内容的标题
                        if self.key_content in content or \
                           self.key_else in content:
                            # webbrowser.open(href)
                            print(href, pdate, title)
        else:
            print(Fore.RED + '查询的网页已失效，请检查网址！！！')
        # print('查询页面：', self.url)

    def get_href(self, item):
        return item.attrs['href']

    def get_title(self, item):
        try:
            return item.attrs['title']
        except Exception as e:
            print(e)
            return ''

    def get_date(self, date):
        if '：' in date:
            pdate = date.split(' ')[0].split('：')[1]
        else:
            pdate = date.split(' ')[0]
        return pdate

    def chk_title(self, title):
        for word in self.exp_words:
            if word in title:
                return False
        return True

    def get_response(self, url):
        try:
            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; '
                       'WOW64) AppleWebKit/537.36 (KHTML, like Gecko) '
                       'Chrome/63.0.3239.108 Safari/537.36'}
            # proxies = {'http': 'http://219.141.153.41:80'}
            proxies = {'http': ''}
            r = self.session.get(url, headers=headers, proxies=proxies,
                                 timeout=18, verify=self.vf)
            r.encoding = 'utf-8'
            return r
        except requests.exceptions.RequestException as e:
            print('连接错误:', e)
            return None


class Gdzb(Bids):  # 国电招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div.lb-link ul li a'
        self.sel_content = 'div.WordSection1'
        self.sel_pubdate = 'div.ninfo-title span'

    def get_result(self):
        for i in range(1):
            self.url = 'http://www.cgdcbidding.com/ggsb/index.jhtml'
            super().get_result()
        print(Fore.BLUE + '国电招标公告查询完毕！')


class Hrzb(Bids):  # 华润招标（网页编码）
    def __init__(self):
        super().__init__()
        self.key_else = '风电机组'
        self.sel_title = 'tbody tr td a'
        self.sel_content = 'table'
        self.sel_pubdate = 'div.ewb-con-info span'

    def get_result(self):
        for i in range(1, 4):
            if i == 1:
                self.url = ('http://www.crpsz.com/zbxx/006001/006001001/'
                            'secondpagejy.html')
            else:
                self.url = ('http://www.crpsz.com/zbxx/006001/006001001/'
                            '%d.html' % i)
            super().get_result()
        print(Fore.YELLOW + '华润招标公告查询完毕！')

    def get_href(self, item):
        return 'http://www.crpsz.com' + item.attrs['href']

    def get_title(self, item):
        try:
            return item.text.split('\n')[1]
        except Exception:
            return ''


class Hdzb(Bids):  # 华电招标（证书验证）
    def __init__(self):
        super().__init__()
        self.key_else = '风电机组'
        self.sel_title = 'tbody tr td.td_2 a'
        self.sel_content = 'html'
        self.sel_pubdate = 'div.headline dl dd'
        self.vf = True

    def get_result(self):
        for i in range(1, 2):
            self.url = ('https://www.chdtp.com/webs/queryWebZbgg.action?'
                        'zbggType=1&page.currentpage=%d' % i)
            super().get_result()
        print(Fore.RED + '华电招标公告查询完毕！')

    def get_href(self, item):
        return ('https://www.chdtp.com/staticPage/' +
                item.attrs['href'].split("'")[1])


class Hnzb(Bids):  # 华能招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'ul.main_r_con li a'
        self.sel_content = 'div.detail_box'
        self.sel_pubdate = 'i'
        self.exp_words = ['检修', '检测', '改造', '定检', '叶片', '备品',
                          '施工', '监理', '自动化', '电缆', '通信', '光缆',
                          '吸污车', '集电', '收购', '开关', '咨询', '安装',
                          '勘察', '物资', '道路', '备件', '送出', '报告',
                          '勘探']

    def get_result(self):
        for i in range(5):
            self.url = ('http://ec.chng.com.cn/ecmall/more.do?'
                        'type=103&start=%d&limit=10' % (i*10))
            super().get_result()
        print(Fore.BLUE + '华能招标公告查询完毕！')

    def get_href(self, item):
        return ('http://ec.chng.com.cn/ecmall/announcement/'
                'announcementDetail.do?announcementId=' +
                item.attrs['href'].split("'")[1])


class Hbzb(Bids):  # 河北建投招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'ul.ewb-con-item li a'
        self.sel_content = 'div.details-info'
        self.sel_pubdate = 'span.article-date'
        self.exp_words = ['运输', '安装', '制氢']

    def get_result(self):
        for i in range(1, 4):
            self.url = ('http://hebeibidding.com/TPFront/xmxx/016001/?'
                        'Paging=%d' % i)
            super().get_result()
        print(Fore.GREEN + '河北建投招标公告查询完毕！')

    def get_href(self, item):
        return 'http://hebeibidding.com' + item.attrs['href']


class Gnzb(Bids):  # 国能招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'ul.right-items li div a'
        self.sel_content = 'div.article'
        self.sel_pubdate = 'p.info-sources'
        self.exp_words = ['运输', '吊装', '安装', '基础', '塔筒', '施工',
                          '维护', '监理', '改造', '电气', '法兰', '电缆',
                          '无功', '主变', '二次', '开关', '箱变', '备件']

    def get_result(self):
        for i in range(1, 5):
            self.url = ('http://www.chnenergybidding.com.cn/bidweb/001/'
                        '001002/001002001/%d.html' % i)
            super().get_result()
        print(Fore.MAGENTA + '国家能源招标公告查询完毕！')

    def get_href(self, item):
        return 'http://www.chnenergybidding.com.cn' + item.attrs['href']

    def get_title(self, item):
        try:
            return item.text
        except Exception:
            return ''


class Xhzb(Bids):  # 协合招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div.news-wrap ul li a'
        self.sel_content = 'div.detail-content'
        self.sel_pubdate = 'p.datetime'
        self.exp_words = ['塔筒', '锚栓', '吊装', '叶片', '线路', '箱变',
                          '监理', '道路', '升压']

    def get_result(self):
        warnings.filterwarnings("ignore")  # 忽略InsecureRequestWarning
        self.url = 'http://www.cnegroup.com/zh/bid/index.html'
        super().get_result()
        print(Fore.BLUE + '协合招标公告查询完毕！')

    def get_href(self, item):
        return 'http://www.cnegroup.com' + item.attrs['href']

    def get_title(self, item):
        try:
            return item.text
        except Exception:
            return ''


class Gtzb(Bids):  # 国投招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div table tbody tr'
        self.sel_content = 'div.dg-notice-detail'
        self.sel_pubdate = 'div.dg-notice-state'
        self.exp_words = ['技术', '齿轮', '电缆', '升压', '主变', '开关',
                          'SVG', 'GIS']

    def get_result(self):
        warnings.filterwarnings("ignore")  # 忽略InsecureRequestWarning
        for i in range(1, 3):
            self.url = ('https://www.sdicc.com.cn/cgxx/ggList?caiGouDanWei='
                        '&gcName=&zbFangShi=1&xmLeiXing=&startTime=&endTime'
                        '=&ggName=&currentPage=%d' % i)
            super().get_result()
        print(Fore.YELLOW + '国投招标公告查询完毕！')

    def get_href(self, item):
        url = item.attrs['onclick']
        id1 = url.split("'")[1]
        id2 = url.split("'")[3]
        return ('https://www.sdicc.com.cn/cgxx/ggDetail?gcGuid='
                + id2 + '&ggGuid=' +id1)

    def get_title(self, item):
        try:
            return item.text.splitlines()[1]
        except Exception:
            return ''

    def get_date(self, date):
        return date.split('：')[1].split(')')[0]


class Znjzb(Bids):  # 中能建招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div.list01 span a'

    def get_result(self):
        self.url = 'http://ec.ceec.net.cn/HomeInfo/ProjectList.aspx'
        response = self.get_response(self.url)
        response.encoding = 'gb2312'
        if response:
            item_list = response.html.find(self.sel_title)
            for item in item_list:
                href = 'http://ec.ceec.net.cn/HomeInfo/' + item.attrs['href']
                title = item.attrs['title']
                if self.key_title in title:
                    print(href, title)
        else:
            print(Fore.RED + '查询的网页已失效，请检查网址！！！')
        print(Fore.BLUE + '中国能建招标公告查询完毕！')


class Zdjzb(Bids):  # 中电建招标（遍历双列表）
    def __init__(self):
        super().__init__()
        self.sel_title = 'div ul li a'
        self.sel_value = 'div ul li input'

    def get_result(self):
        warnings.filterwarnings("ignore")  # 忽略InsecureRequestWarning
        self.url = ('https://ec.powerchina.cn/zgdjcms/category/'
                    'bulletinList.html?startPublishDate=&endPublishDate=&'
                    'word=风力&categoryId=2&tabName=&purType=设备类')
        response = self.get_response(self.url)
        if response:
            item_title = response.html.find(self.sel_title)
            item_url = response.html.find(self.sel_value)
            # print(len(item_title), len(item_url))
            for item, url in zip(item_title, item_url):
                href = 'https:' + url.attrs['value']
                title = item.attrs['title']
                #title = item.text
                print(href, title)
        else:
            print(Fore.RED + '查询的网页已失效，请检查网址！！！')
        print(Fore.GREEN + '中国电建招标公告查询完毕！')


class Gjdtzb(Bids):  # 国家电投招标（412 Precondition Failed）
    def __init__(self):
        super().__init__()
        self.sel_title = 'div.article_list_lb ul li a'

    def get_result(self):
        url = 'http://www.cpeinet.com.cn/cpcec/bul/bul_list.jsp?type=1'
        headers = { 'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36'}
        cookies = ''  # 网站随时更新
        cookies_dict ={i.split('=')[0]:i.split('=')[1] for i in cookies.split('; ')}
        # print(cookies_dict)
        response = self.session.get(url, headers=headers, cookies=cookies_dict)
        print(response)
        if response:
            item_list = response.html.find(self.sel_title)
            print(item_list)
            for item in item_list:
                page = item.attrs['onclick'].split('(')[1].split(',')[0]
                href = ('http://www.cpeinet.com.cn/cpcec/bul/'
                        'bulletin_show.jsp?id=' + page)
                title = item.attrs['title']
                if self.key_title in title:
                    print(href, title)
        else:
            print(Fore.RED + '国家电投网页已失效，请检查网址！！！')
        print(Fore.YELLOW + '国家电投招标公告查询完毕！')


class Sxzb(Bids):  # 三峡招标（动态加载，获取json文件）
    def __init__(self):
        super().__init__()
        self.key_title = '风电'
        self.sel_title = ''
        self.sel_content = 'html'

    def get_result(self):
        for i in range(2):
            self.url = ('http://epp.ctg.com.cn/index/getData.do?'
                        'queryName=ctg.list.zbgg&page=%d&rows=15' % i)
            response = self.get_response(self.url)
            item_list = response.json()['rows']
            for item in item_list:
                t = time.time()
                href = 'http://epp.ctg.com.cn/static/temphtml/' + \
                    item['ARTICLE_ID'] + '.html?_=' + str(round(t * 1000))
                title = item['TITLE']
                pdate = item['CREATED_TIME']
                if self.key_title in title or self.key_else in title:
                    response = self.get_response(href)
                    content = response.html.find(self.sel_content,
                                                 first=True).text
                    if self.key_content in content:
                        # webbrowser.open(href)
                        print(href, pdate, title)
        print(Fore.YELLOW + '三峡招标公告查询完毕！')


class Dtzb(Bids):  # 大唐招标
    def __init__(self):
        super().__init__()

    def get_result(self):
        for i in range(1, 5):
            self.url = ('http://www.cdt-ec.com/potal-web/pendingGxnotice/'
                        'where?message_type=0&pageno=%d&pagesize=15' % i)
            response = self.get_response(self.url)
            item_list = response.json()
            for item in item_list:
                title = item['message_title']
                href = item['pdf_url']
                t = item['publish_time']/1000
                pdate = str(datetime.datetime.fromtimestamp(t)).split(' ')[0]
                if self.key_title in title:
                    print(href, pdate, title)
        print(Fore.RED + '大唐招标公告查询完毕！')


class Zghzb(Bids):  # 中广核招标
    def __init__(self):
        super().__init__()

    def get_result(self):
        self.vf = True
        url1 = 'https://ecp.cgnpc.com.cn/content/'
        urlid = '567dafa9ae447eea50584d794e5ad5d8'
        url2 = '/350ea2d859f7a2797c9be4b6cb3b5ebe/'
        urld = 'https://ecp.cgnpc.com.cn/Details.html'
        dataid = 'dataId=65e43b2fbc914f7e98d966d85f78d5de'
        # detailid = 'detailId=b1137c339481451198419c9a9308e353'
        for i in range(1, 2):
            self.url = ('%s%s%s%d.json' % (url1, urlid, url2, i))
            response = self.get_response(self.url)
            item_list = response.json()['list']
            # print(item_list)
            for item in item_list:
                title = item['Title']
                did = item['Id']
                href = ('%s?%s&detailId=%s' % (urld, dataid, did))
                pdate = item['CreateTime'].split(' ')[0]
                if self.key_title in title or self.key_else in title:
                    print(href, pdate, title)
        print(Fore.MAGENTA + '中广核招标公告查询完毕！')


class Sftzb(Bids):  # 山东发展招标（json文件）
    def __init__(self):
        super().__init__()
        self.sel_content = 'html'

    def get_result(self):
        url1 = ('http://www.ygcgfw.com/ygcgwebbuilder/'
                'ZBidInfoAction.action?cmd=RightInfoList&vname=%2Ftpfront&'
                'cate=001001&pageSize=10&pageIndex=')
        url2 = '&ssqy=&xmbh=&ggmc=&cglb='
        for i in range(4):
            self.url = ('%s%d%s' % (url1, i, url2))
            response = self.get_response(self.url)
            text = response.json()['custom']
            item_list = json.loads(text)['rightInfoList']
            # print(item_list)
            for item in item_list:
                href = 'http://www.ygcgfw.com' + item['solution']
                title = item['realtitle']
                pdate = item['date']
                # print(href, pdate, title)
                if self.key_title in title or self.key_else in title:
                    response = self.get_response(href)
                    content = response.html.find(self.sel_content,
                                                 first=True).text
                    if self.key_content in content:
                        # webbrowser.open(href)
                        print(href, pdate, title)
        print(Fore.RED + '山东发展招标公告查询完毕！')


class Zhzb(Bids):  # 中核招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div.List1 ul li a'
        self.sel_content = 'div.WordSection1'
        self.sel_pubdate = 'div.Padding10'

    def get_result(self):
        warnings.filterwarnings("ignore")  # 忽略InsecureRequestWarning
        self.url = 'https://www.cnncecp.com/xzbgg/index.jhtml'
        super().get_result()
        print(Fore.YELLOW + '中核集团招标公告查询完毕！')

    def get_href(self, item):
        return 'https://www.cnncecp.com' + item.attrs['href']

    def get_title(self, item):
        try:
            return item.text
        except Exception:
            return ''

    def get_date(self, date):
        return date.split(' ')[1]


class Snzb(Bids):  # 深能招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div ul li a'
        self.sel_content = 'div.WordSection1'
        self.sel_pubdate = 'div.TxtCenter'

    def get_result(self):
        warnings.filterwarnings("ignore")  # 忽略InsecureRequestWarning
        self.url = 'https://zb.sec.com.cn/zbggs/index.jhtml'
        super().get_result()
        print(Fore.BLUE + '深圳能源招标公告查询完毕！')

    def get_href(self, item):
        return 'https://zb.sec.com.cn' + item.attrs['href']

    def get_title(self, item):
        try:
            return item.text
        except Exception:
            return ''


class Jnzb(Bids):  # 京能招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div ul li a'

    def get_result(self):
        warnings.filterwarnings("ignore")  # 忽略InsecureRequestWarning
        self.url = ('https://www.powerbeijing-ec.com/jncms/search/'
                    'bulletin.html?dates=300&categoryId=2&tabName=招标公告'
                    '&page=1')
        response = self.get_response(self.url)
        if response:
            item_list = response.html.find(self.sel_title)
            # print(item_list)
            for item in item_list:
                href = item.attrs['href']
                # title = item.text.split('\n')[0]
                # pdate = item.text.split('\n')[1]
                title = item.text.splitlines()[0]
                if self.key_title in title or self.key_else in title:
                    print(href, title)
        else:
            print(Fore.RED + '查询的网页已失效，请检查网址！！！')
        print(Fore.GREEN + '北京京能招标公告查询完毕！')


class Zjnzb(Bids):  # 中节能招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div ul li a'

    def get_result(self):
        self.url = ('http://www.ebidding.cecep.cn/'
                    'jyxx/001006/001006001/bidinfo.html')
        response = self.get_response(self.url)
        if response:
            item_list = response.html.find(self.sel_title)
            # print(item_list)
            for item in item_list:
                href = 'http://www.ebidding.cecep.cn' + item.attrs['href']
                title = item.text.split(' ')[0]
                if self.key_title in title or self.key_else in title:
                    print(href, title)
        else:
            print(Fore.RED + '查询的网页已失效，请检查网址！！！')
        print(Fore.MAGENTA + '中国节能招标公告查询完毕！')


class Cebpub(Bids):  # 招投标公共服务平台（使用滑动验证码）
    def __init__(self):
        super().__init__()
        self.sel_title = 'table tbody tr td a'
        self.exp_words = ['运输', '安装', '塔筒']

    def get_result(self):
        today = datetime.date.today()
        date = today + datetime.timedelta(days=-3)
        print(today)
        try:
            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; '
                       'WOW64) AppleWebKit/537.36 (KHTML, like Gecko) '
                       'Chrome/63.0.3239.108 Safari/537.36',
                       'referer': 'https://www.cebpubservice.com/',}
            cookies = ''  # 网站随时更新
            cookies_dict ={i.split('=')[0]:i.split('=')[1] for i in cookies.split('; ')}
            print(cookies_dict)
            searchurl = 'http://www.cebpubservice.com/ctpsp_iiss/' \
                        'searchbusinesstypebeforedooraction/' \
                        'getStringMethod.do'
            for i in range(1, 2):
                data = {
                    'searchName': '风力',
                    'searchArea': '',
                    'searchIndustry': '',
                    'centerPlat': '',
                    'businessType': '招标公告',
                    'searchTimeStart': '',
                    'searchTimeStop': '',
                    'timeTypeParam': '',
                    'bulletinIssnTime': '1周',
                    'bulletinIssnTimeStart': '',
                    'bulletinIssnTimeStop': '',
                    'pageNo': i,
                    'row': 15,
                    }
                #response = self.session.post(searchurl, headers=headers,
                #                             params=data, timeout=8)
                response = self.session.get(searchurl, headers=headers,
                                        params=data, cookies=cookies_dict)
                item_list = response.html.find(self.sel_title)
                print(response)
                print(response.text)
                # print(item_list)
                if item_list:
                    for item in item_list:
                        href = self.get_href(item).split("'")[1]
                        title = self.get_title(item)
                        sdate = href.split('/')[4]
                        cdate = datetime.datetime.strptime(sdate, '%Y-%m-%d')
                        ddate = datetime.datetime.date(cdate)
                        # print(ddate, type(ddate), date, type(date))
                        if ddate > date:
                            if self.chk_title(title):
                                if self.key_content in title:
                                    print(href, '\n', ddate, title)
        except requests.exceptions.RequestException as e:
            print(e)
        print(Fore.GREEN + '招投标公共平台查询完毕！')


def zbgg():
    # 国电招标
    # gdzb = Gdzb()
    # gdzb.get_result()
    # 招投标公共平台
    # cebpub = Cebpub()
    # cebpub.get_result()
    # 国家电投招标[412]
    # gjdtzb = Gjdtzb()
    # gjdtzb.get_result()
    # 华电招标
    hdzb = Hdzb()
    hdzb.get_result()
    # 华润招标
    hrzb = Hrzb()
    hrzb.get_result()
    # 华能招标
    hnzb = Hnzb()
    hnzb.get_result()
    # 国能招标
    gnzb = Gnzb()
    gnzb.get_result()
    # 河北建投招标
    hbzb = Hbzb()
    hbzb.get_result()
    # 协合招标
    xhzb = Xhzb()
    xhzb.get_result()
    # 三峡招标
    sxzb = Sxzb()
    sxzb.get_result()
    # 大唐招标
    dtzb = Dtzb()
    dtzb.get_result()
    # 中能建招标
    znjzb = Znjzb()
    znjzb.get_result()
    # 中广核招标
    zghzb = Zghzb()
    zghzb.get_result()
    # 国投招标
    gtzb = Gtzb()
    gtzb.get_result()
    # 山发展招标
    sftzb = Sftzb()
    sftzb.get_result()
    # 深能招标
    snzb = Snzb()
    snzb.get_result()
    # 京能招标
    jnzb = Jnzb()
    jnzb.get_result()
    # 中核招标
    zhzb = Zhzb()
    zhzb.get_result()
    # 中节能招标
    zjnzb = Zjnzb()
    zjnzb.get_result()
    '''
    # 中电建招标(邀标)
    zdjzb = Zdjzb()
    zdjzb.get_result()
    '''

    from allbids import Bidding
    chinabidding = Bidding('https://www.chinabidding.cn', 20)
    chinabidding.get_result()
    # os.system('pause')

if __name__ == "__main__":
    RUN = 1
    if RUN:
        zbgg()
    else:
        # 中节能招标
        zjnzb = Zjnzb()
        zjnzb.get_result()

