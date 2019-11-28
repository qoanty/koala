# coding:utf-8
__author__ = 'chenke'

from requests_html import HTMLSession
import requests
import time
import datetime
import os
# import webbrowser
import warnings
from colorama import init, Fore  # Back, Style


class Bids:
    def __init__(self):
        self.key_title = '风力发电'         # 标题关键字
        self.key_else = '风电机组'          # 标题关键字
        self.key_content = '风力发电机组'   # 内容关键字
        self.exp_words = []
        self.sel_title = ''
        self.sel_content = ''
        self.sel_pubdate = ''
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
                        if '：' in pubdate:
                            pdate = pubdate.split(' ')[0].split('：')[1]
                        else:
                            pdate = pubdate.split(' ')[0]
                        # print(href, pdate, title)  # 查询内容的标题
                        # print(content)
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
                                 timeout=8)  # verify = False
            r.encoding = 'utf-8'
            return r
        except requests.exceptions.RequestException as e:
            print('连接错误:', e)
            return None


class Gdzb(Bids):  # 国电招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div.lb-link > ul > li > a'
        self.sel_content = 'div.WordSection1'
        self.sel_pubdate = 'div.ninfo-title > span'

    def get_result(self):
        for i in range(1):
            self.url = 'http://www.cgdcbidding.com/ggsb/index.jhtml'
            super().get_result()
        print(Fore.BLUE + '国电招标公告查询完毕！')


class Hrzb(Bids):  # 华润招标（网页编码）
    def __init__(self):
        super().__init__()
        self.key_title_else = '风电机组'
        self.sel_title = 'tbody > tr > td > a'
        self.sel_content = 'table'
        self.sel_pubdate = 'div.ewb-con-info > span'

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
            return item.text
        except Exception:
            return ''


class Hdzb(Bids):  # 华电招标（证书验证）
    def __init__(self):
        super().__init__()
        self.key_title_else = '风电机组'
        self.sel_title = 'a'
        self.sel_content = 'div.Basic_information'
        self.sel_pubdate = 'div.headline > dl > dd'

    def get_result(self):
        warnings.filterwarnings("ignore")  # 忽略InsecureRequestWarning
        for i in range(1, 2):
            self.url = ('https://www.chdtp.com/webs/queryWebZbgg.action?'
                        'zbggType=1&page.pageSize=31&page.currentpage=%d' % i)
            super().get_result()
        print(Fore.RED + '华电招标公告查询完毕！')

    def get_href(self, item):
        return ('https://www.chdtp.com/staticPage/' +
                item.attrs['href'].split("'")[1])


class Hnzb(Bids):  # 华能招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'ul.main_r_con > li > a'
        self.sel_content = 'div.detail_box'
        self.sel_pubdate = 'i'

    def get_result(self):
        for i in range(5):
            self.url = ('http://ec.chng.com.cn/ecmall/more.do?'
                        'type=103&start=%d&limit=10' % (i*10))
            super().get_result()
        print(Fore.CYAN + '华能招标公告查询完毕！')

    def get_href(self, item):
        return ('http://ec.chng.com.cn/ecmall/announcement/'
                'announcementDetail.do?announcementId=' +
                item.attrs['href'].split("'")[1])


class Hbzb(Bids):  # 河北建投招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'ul.ewb-con-item > li > a'
        self.sel_content = 'div.details-info'
        self.sel_pubdate = 'span.article-date'
        self.exp_words = ['运输', '安装']

    def get_result(self):
        for i in range(1, 4):
            self.url = ('http://hebeibidding.com/TPFront/xmxx/016001/?'
                        'Paging=%d' % i)
            super().get_result()
        print(Fore.GREEN + '河北建投招标公告查询完毕！')

    def get_href(self, item):
        return 'http://hebeibidding.com' + item.attrs['href']


class Shzb(Bids):  # 神华招标
    def __init__(self):
        super().__init__()
        self.key_title = '风电'
        self.sel_title = 'ul.right-items > li > div > a'
        self.sel_content = 'div.article'
        self.sel_pubdate = 'p.info-sources'
        self.exp_words = ['运输', '吊装', '安装', '基础', '塔筒', '施工',
                          '维护', '监理', '改造', '电气', '法兰', '电缆',
                          '无功', '主变', '二次', '开关']

    def get_result(self):
        for i in range(1, 5):
            self.url = ('http://www.shenhuabidding.com.cn/bidweb/001/'
                        '001002/001002001/%d.html' % i)
            super().get_result()
        print(Fore.MAGENTA + '神华招标公告查询完毕！')

    def get_href(self, item):
        return 'http://www.shenhuabidding.com.cn' + item.attrs['href']


class Xhzb(Bids):  # 协合招标
    def __init__(self):
        super().__init__()
        self.key_title = '风电'
        self.sel_title = 'div.news-wrap > ul > li > a'
        self.sel_content = 'div.detail-content'
        self.sel_pubdate = 'p.datetime'
        self.exp_words = ['塔筒', '锚栓', '吊装', '叶片', '线路', '箱变']

    def get_result(self):
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


class Zghzb(Bids):  # 中广核招标（动态加载）
    def __init__(self):
        super().__init__()
        self.sel_title = 'ul > li > a'

    def get_result(self):
        warnings.filterwarnings("ignore")  # 忽略InsecureRequestWarning
        for i in range(1, 3):
            self.url = ('https://ecp.cgnpc.com.cn/CmsNewsController.do?'
                        'method=recommendBulletinList&index=provincebuy'
                        'Bulletin&channelCode=zgh_zbgg&rp=20&page=%d' % i)
            response = self.get_response(self.url)
            if response:    # 获取对象不为空
                item_list = response.html.find(self.sel_title)
                # print(item_list)   # 标题列表
                for item in item_list:
                    href = self.get_href(item)      # 获取URL
                    title = self.get_title(item)    # 获取标题文本
                    if self.key_title in title:
                        print(href, title)
            else:
                print(Fore.RED + '查询的网页已失效，请检查网址！！！')
        print(Fore.MAGENTA + '中广核招标公告查询完毕！')

    def get_href(self, item):
        return 'https://ecp.cgnpc.com.cn' + item.attrs['href']


class Znjzb(Bids):  # 中能建招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div.list01 > span > a'

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


class Gjdtzb(Bids):  # 国家电投招标
    def __init__(self):
        super().__init__()
        self.sel_title = 'div.article_list_lb ul li a'

    def get_result(self):
        self.url = 'http://www.cpeinet.com.cn/cpcec/bul/bul_list.jsp?type=1'
        response = self.get_response(self.url)
        if response:
            item_list = response.html.find(self.sel_title)
            for item in item_list:
                page = item.attrs['onclick'].split('(')[1].split(',')[0]
                href = ('http://www.cpeinet.com.cn/cpcec/bul/'
                        'bulletin_show.jsp?id=' + page)
                title = item.attrs['title']
                if self.key_title in title:
                    print(href, title)
        else:
            print(Fore.RED + '查询的网页已失效，请检查网址！！！')
        print(Fore.CYAN + '国家电投招标公告查询完毕！')


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
                if self.key_title in title:
                    response = self.get_response(href)
                    content = response.html.find(self.sel_content,
                                                 first=True).text
                    if self.key_content in content:
                        # webbrowser.open(href)
                        print(href, title)
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
                if self.key_title in title:
                    print(href, title)
        print(Fore.RED + '大唐招标公告查询完毕！')


class Cebpub(Bids):  # 招投标公共服务平台
    def __init__(self):
        super().__init__()
        self.sel_title = 'table tr td a'
        self.exp_words = ['运输', '安装', '塔筒']

    def get_result(self):
        today = datetime.date.today()
        date = today + datetime.timedelta(days=-3)
        print(today)
        try:
            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; '
                       'WOW64) AppleWebKit/537.36 (KHTML, like Gecko) '
                       'Chrome/63.0.3239.108 Safari/537.36'}
            searchurl = 'http://bulletin.cebpubservice.com/xxfbcmses/' \
                        'search/bulletin.html'
            for i in range(1, 25):
                data = {
                    'searchDate': date,
                    'dates': 3,
                    'word': self.key_content,
                    'categoryId': 88,
                    'industryName': '',
                    'area': '',
                    'status': '',
                    'publishMedia': '',
                    'sourceInfo': '',
                    'showStatus': '',
                    'page': i,
                    }
                response = self.session.get(searchurl, headers=headers,
                                            params=data, timeout=8)
                item_list = response.html.find(self.sel_title)
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


if __name__ == "__main__":
    # 国电招标
    # gdzb = Gdzb()
    # gdzb.get_result()
    # 招投标公共平台
    cebpub = Cebpub()
    cebpub.get_result()
    # 华润招标
    hrzb = Hrzb()
    hrzb.get_result()
    # 华电招标
    hdzb = Hdzb()
    hdzb.get_result()
    # 华能招标
    hnzb = Hnzb()
    hnzb.get_result()
    # 神华招标
    shzb = Shzb()
    shzb.get_result()
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
    # 国家电投招标
    gjdtzb = Gjdtzb()
    gjdtzb.get_result()
    # 中能建招标
    znjzb = Znjzb()
    znjzb.get_result()
    # 中广核招标
    zghzb = Zghzb()
    zghzb.get_result()

    from allbids import Bidding
    chinabidding = Bidding('https://www.chinabidding.cn', 20)
    chinabidding.get_result()
    os.system('pause')
