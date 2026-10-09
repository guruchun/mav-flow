from PIL import Image
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPM
import os

# SVG 파일 경로
svg_path = r'd:\GitHub\mav-flow\assets\icons\eos_drone_256.svg'
png_path = r'd:\GitHub\mav-flow\assets\icons\eos_drone_256.png'

# SVG 파일 읽기 및 색상 변경
with open(svg_path, 'r') as f:
    svg_content = f.read()

# currentColor를 실제 색상으로 대체 (Material Blue)
svg_content_blue = svg_content.replace('currentColor', '#1976D2')

# 임시 파일에 저장
temp_svg = r'd:\GitHub\mav-flow\assets\icons\temp_drone.svg'
with open(temp_svg, 'w') as f:
    f.write(svg_content_blue)

# SVG를 PNG로 변환
drawing = svg2rlg(temp_svg)
if drawing:
    # 스케일 조정 (원본이 24x24이므로 256/24 = ~10.67배)
    scale = 256 / 24
    drawing.width = 256
    drawing.height = 256
    drawing.scale(scale, scale)
    
    renderPM.drawToFile(drawing, png_path, fmt="PNG")
    print(f'Converted: {png_path}')
    print(f'Size: {os.path.getsize(png_path)} bytes')
else:
    print('Failed to load SVG')

# 임시 파일 삭제
os.remove(temp_svg)

# 흰색 버전도 생성 (다크 모드용)
svg_content_white = svg_content.replace('currentColor', '#FFFFFF')
with open(temp_svg, 'w') as f:
    f.write(svg_content_white)

drawing = svg2rlg(temp_svg)
if drawing:
    scale = 256 / 24
    drawing.width = 256
    drawing.height = 256
    drawing.scale(scale, scale)
    
    white_png_path = r'd:\GitHub\mav-flow\assets\icons\eos_drone_white_256.png'
    renderPM.drawToFile(drawing, white_png_path, fmt="PNG")
    print(f'White version: {white_png_path}')

os.remove(temp_svg)
print('Done!')
