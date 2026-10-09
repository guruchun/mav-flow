from PIL import Image
import os

# 소스 이미지
src_path = r'd:\GitHub\mav-flow\assets\icons\app_icon_256.png'
ico_path = r'd:\GitHub\mav-flow\windows\runner\resources\app_icon.ico'

# 원본 이미지 로드
img = Image.open(src_path)
print(f'Source: {img.size}, mode: {img.mode}')

# RGBA로 변환 (투명도 지원)
if img.mode != 'RGBA':
    img = img.convert('RGBA')

# ICO에 포함할 크기들
sizes = [16, 32, 48, 64, 128, 256]

# 각 크기의 이미지 생성
images = []
for size in sizes:
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    images.append(resized)
    print(f'  Created {size}x{size}')

# ICO 파일 저장 (Pillow 방식)
# 가장 큰 이미지를 기준으로 저장
img_256 = images[-1]  # 256x256
img_256.save(
    ico_path,
    format='ICO',
    sizes=[(s, s) for s in sizes]
)

print(f'\nCreated: {ico_path}')
print(f'Size: {os.path.getsize(ico_path)} bytes')

# 원본 ICO 백업 확인
orig_ico = r'd:\GitHub\mav-flow\windows\runner\resources\app_icon_orig.ico'
if not os.path.exists(orig_ico):
    # Flutter 기본 아이콘이 있었다면 백업
    pass

print('Done!')
