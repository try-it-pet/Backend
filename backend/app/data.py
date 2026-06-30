from .models import Product

# 카테고리 5 대분류 (Pawdy 기획서)
CATEGORIES = [
    {"key": "care", "label": "데일리케어", "subs": ["샴푸", "브러쉬", "덴탈케어", "위생용품", "사료", "간식", "영양제"]},
    {"key": "fashion", "label": "패션·스타일", "subs": ["의류", "하네스", "리드줄", "액세서리", "코스튬"]},
    {"key": "active", "label": "액티브·아웃도어", "subs": ["산책용품", "유모차", "이동가방", "카시트", "장난감", "훈련용품"]},
    {"key": "wellness", "label": "헬스·웰니스", "subs": ["건강보조제", "관절케어", "피부케어", "체중관리"]},
    {"key": "home", "label": "홈·인테리어", "subs": ["캣타워", "숨숨집", "쿠션", "하우스", "스크래처", "터널", "급수기"]},
]

# 펫 전문 멀티샵 더미 카탈로그. fittable=착용/배치 미리보기 가능(패션·홈 일부).
PRODUCTS: list[Product] = [
    # 패션·스타일 (착용 피팅) — ref_image: 실제 상품컷(정적 파일). AI 피팅이 이 옷을 입힘.
    Product(id=0, brand="무무펫", name="코지 니트 스웨터", price=28000, fit=96, category="fashion", species="dog", fittable=True, ref_image="/static/garments/0.png"),
    Product(id=1, brand="도그웨어", name="체크 하네스 세트", price=34000, fit=89, category="fashion", species="dog", fittable=True, ref_image="/static/garments/1.png"),
    Product(id=2, brand="펫코", name="경량 패딩 베스트", price=42000, fit=94, category="fashion", species="dog", fittable=True, ref_image="/static/garments/2.png"),
    Product(id=3, brand="모카독", name="데일리 후디", price=25000, fit=92, category="fashion", species="dog", fittable=True, ref_image="/static/garments/3.png"),
    Product(id=4, brand="무무펫", name="윈터 울 코트", price=48000, fit=90, category="fashion", species="dog", fittable=True, ref_image="/static/garments/4.png"),
    Product(id=5, brand="캣무드", name="니트 캣 코스튬", price=21000, fit=88, category="fashion", species="cat", fittable=True, ref_image="/static/garments/5.png"),
    # 데일리케어
    Product(id=6, brand="퓨어펫", name="약산성 저자극 샴푸", price=16000, fit=91, category="care", species="all", fittable=False),
    Product(id=7, brand="치카독", name="덴탈케어 껌 30개입", price=9000, fit=87, category="care", species="dog", fittable=False),
    Product(id=8, brand="네이처바울", name="자연식 연어 사료 2kg", price=38000, fit=95, category="care", species="all", fittable=False),
    Product(id=9, brand="리얼바이트", name="동결건조 닭가슴살 간식", price=14000, fit=90, category="care", species="all", fittable=False),
    # 액티브·아웃도어
    Product(id=10, brand="워크업", name="가벼운 산책 리드줄", price=22000, fit=89, category="active", species="dog", fittable=False),
    Product(id=11, brand="트래블펫", name="반려동물 4륜 유모차", price=159000, fit=92, category="active", species="all", fittable=True),
    Product(id=12, brand="플레이펫", name="노즈워크 코끼리 장난감", price=18000, fit=88, category="active", species="dog", fittable=False),
    # 헬스·웰니스
    Product(id=13, brand="헬스독", name="관절 글루코사민 영양제", price=32000, fit=93, category="wellness", species="dog", fittable=False),
    Product(id=14, brand="스킨펫", name="피부 보습 미스트", price=15000, fit=86, category="wellness", species="all", fittable=False),
    # 홈·인테리어 (배치 피팅)
    Product(id=15, brand="코지캣", name="3단 원목 캣타워", price=89000, fit=94, category="home", species="cat", fittable=True),
    Product(id=16, brand="하우스펫", name="포근 숨숨집 텐트", price=26000, fit=90, category="home", species="all", fittable=True),
    Product(id=17, brand="워터펫", name="자동 순환 급수기", price=34000, fit=88, category="home", species="all", fittable=False),
]

PRODUCTS_BY_ID = {p.id: p for p in PRODUCTS}
