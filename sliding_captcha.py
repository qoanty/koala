# coding:utf-8
__author__ = 'chenke'

from selenium import webdriver
from selenium.webdriver import ActionChains
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait
from PIL import Image
from io import BytesIO
import time

BORDER = 6


class CrackGeetest():
    def __init__(self):
        self.url = 'https://www.geetest.com/type/'
        self.browser = webdriver.Chrome('F:/chromedriver')
        self.wait = WebDriverWait(self.browser, 10)

    def open(self):
        '''打开网页'''
        self.browser.get(self.url)

    def close(self):
        '''关闭网页'''
        self.browser.close()
        self.browser.quit()

    def change_to_slide(self):
        '''切换为滑动认证'''
        label = self.wait.until(
            EC.element_to_be_clickable((
                By.CSS_SELECTOR, '.products-content ul > li:nth-child(2)'
                )))
        return label

    def get_geetest_button(self):
        '''获取初始认证按钮'''
        button = self.wait.until(
            EC.element_to_be_clickable((
                By.CSS_SELECTOR, '.geetest_radar_tip')))
        return button

    def wait_pic(self):
        '''等待验证图片加载完成'''
        self.wait.until(
            EC.presence_of_element_located((
                By.CSS_SELECTOR, '.geetest_popup_wrap')))

    def get_screenshot(self):
        '''获取整个页面的截图'''
        screenshot = self.browser.get_screenshot_as_png()
        screenshot = Image.open(BytesIO(screenshot))
        # screenshot.show()
        return screenshot

    def get_position(self):
        '''获取验证图片坐标（基于整个页面的截图）'''
        img = self.wait.until(EC.presence_of_element_located((
            By.CLASS_NAME, 'geetest_canvas_img')))
        time.sleep(2)
        location = img.location
        size = img.size
        location['y'] //= 2  # 需调整此值获取有效坐标
        top, bottom = location['y'], location['y'] + size['height']
        left, right = location['x'], location['x'] + size['width']
        return (top, bottom, left, right)

    def get_geetest_image(self, name='captcha.png'):
        '''获取验证码图片（根据坐标在整个页面截图上在截图）'''
        top, bottom, left, right = self.get_position()
        print('验证图片坐标', top, bottom, left, right)
        screenshot = self.get_screenshot()
        captcha = screenshot.crop((left, top, right, bottom))
        captcha.save(name)
        return captcha

    def delete_style(self):
        '''执行js脚本，获取完整验证图片'''
        js = 'document.querySelectorAll("canvas")[2].style=""'
        self.browser.execute_script(js)

    def get_slider(self):
        '''获取滑块对象'''
        slider = self.wait.until(EC.element_to_be_clickable((
            By.CLASS_NAME, 'geetest_slider_button')))
        return slider

    def is_pixel_equal(self, img1, img2, x, y):
        '''判断两个图片的像素是否相同'''
        pix1 = img1.load()[x, y]
        pix2 = img2.load()[x, y]
        threshold = 60
        if abs(pix1[0] - pix2[0]) < threshold \
           and abs(pix1[1] - pix2[1]) < threshold \
           and abs(pix1[2] - pix2[2]) < threshold:
            return True
        else:
            return False

    def get_gap(self, img1, img2):
        '''获取缺口偏移量'''
        left = 60
        for i in range(left, img1.size[0]):
            for j in range(img1.size[1]):
                if not self.is_pixel_equal(img1, img2, i, j):
                    left = i
                    return left
        return left

    def get_track(self, distance):
        '''根据偏移量获取移动轨迹'''
        track = []      # 移动轨迹
        current = 0     # 当前位移
        mid = distance * 3 / 5  # 减速阈值
        t = 0.2         # 计算间隔
        v = 0           # 初速度
        distance += 15  # 滑超过过一段距离
        while current < distance:
            if current < mid:
                a = 1   # 加速度为正
            else:
                a = -0.5  # 加速度为负
            v0 = v          # 初速度 v0
            v = v0 + a * t  # 当前速度 v
            s = v0 * t + 1 / 2 * a * t * t  # 移动距离
            current += s    # 当前位移
            track.append(round(s))  # 加入轨迹
        return track

    def shake_mouse(self):
        '''模拟释放鼠标时的抖动'''
        (ActionChains(self.browser).
         move_by_offset(xoffset=-3, yoffset=0).perform())
        (ActionChains(self.browser).
         move_by_offset(xoffset=3, yoffset=0).perform())

    def move_to_gap(self, slider, tracks):
        '''拖动滑块到缺口处'''
        back_tracks = [-1, -1, -2, -2, -3, -2, -2, -1, -1]
        ActionChains(self.browser).click_and_hold(slider).perform()
        for x in tracks:        # 正向
            ActionChains(self.browser).move_by_offset(
                xoffset=x, yoffset=0).perform()
        time.sleep(0.5)
        for x in back_tracks:   # 逆向
            ActionChains(self.browser).move_by_offset(
                xoffset=x, yoffset=0).perform()
        self.shake_mouse()      # 抖动
        time.sleep(0.5)
        ActionChains(self.browser).release().perform()

    def crack(self):
        try:
            self.open()  # 打开网页
            s_button = self.change_to_slide()  # 转换验证方式并点击按钮
            time.sleep(1)
            s_button.click()
            g_button = self.get_geetest_button()
            g_button.click()
            self.wait_pic()  # 图片加载
            # 获取带缺口的验证码图片
            image1 = self.get_geetest_image('captcha1.png')
            self.delete_style()
            image2 = self.get_geetest_image('captcha2.png')
            gap = self.get_gap(image1, image2)
            print('缺口位置', gap)
            gap -= BORDER
            slider = self.get_slider()  # 获取滑块
            track = self.get_track(gap)
            self.move_to_gap(slider, track)
            success = self.wait.until(
                EC.text_to_be_present_in_element((
                    By.CLASS_NAME, 'geetest_success_radar_tip_content'
                ), '验证成功'))
            print(success)
            time.sleep(5)
            self.close()
        except Exception:
            print('Failed & Retry')
            self.crack()


if __name__ == '__main__':
    geetest = CrackGeetest()
    geetest.crack()
