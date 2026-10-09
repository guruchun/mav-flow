from PIL import Image

# Light mode 로고에서 드론 아이콘 추출 (왼쪽 부분)
img = Image.open(r'd:\GitHub\mav-flow\assets\icons\mavlink_logo_light.png')
print(f'Original size: {img.size}')

# 드론 아이콘은 왼쪽에 위치, 대략 정사각형으로 크롭
# 이미지 높이 기준으로 정사각형 추출
h = img.height
cropped = img.crop((0, 0, h, h))
cropped.save(r'd:\GitHub\mav-flow\assets\icons\mavlink_drone_light.png')
print(f'Cropped light: {cropped.size}')

# Dark mode도 동일하게
img_dark = Image.open(r'd:\GitHub\mav-flow\assets\icons\mavlink_logo_dark.png')
cropped_dark = img_dark.crop((0, 0, img_dark.height, img_dark.height))
cropped_dark.save(r'd:\GitHub\mav-flow\assets\icons\mavlink_drone_dark.png')
print(f'Cropped dark: {cropped_dark.size}')

# 256x256으로 리사이즈 (Windows 아이콘용)
cropped_256 = cropped.resize((256, 256), Image.Resampling.LANCZOS)
cropped_256.save(r'd:\GitHub\mav-flow\assets\icons\app_icon_256.png')
print('Created 256x256 icon')

print('Done!')
