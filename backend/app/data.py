from .models import Product

# 카테고리 5 대분류 (Pawdy 기획서)
CATEGORIES = [
    {"key": "care", "label": "데일리케어", "subs": ["샴푸", "브러쉬", "덴탈케어", "위생용품", "사료", "간식", "영양제"]},
    {"key": "fashion", "label": "패션·스타일", "subs": ["의류", "하네스", "리드줄", "액세서리", "코스튬"]},
    {"key": "active", "label": "액티브·아웃도어", "subs": ["산책용품", "유모차", "이동가방", "카시트", "장난감", "훈련용품"]},
    {"key": "wellness", "label": "헬스·웰니스", "subs": ["건강보조제", "관절케어", "피부케어", "체중관리"]},
    {"key": "home", "label": "홈·인테리어", "subs": ["캣타워", "숨숨집", "쿠션", "하우스", "스크래처", "터널", "급수기"]},
]

# 해외직구 전문 펫샵 카탈로그 — 전부 실제 판매 상품 (2026-07 기준 실브랜드·실가격 환산).
# price = 직구 예상가(KRW, 현지가+배송 감안). url = 원 판매처 상품 페이지.
# image = 실상품컷(app/static/products/{id}.*, 원 판매처 CDN에서 수집).
# fittable 패션 상품은 ref_image(옷 레퍼런스) = 실상품 플랫레이 컷 → AI 피팅이 이 옷을 입힘.
PRODUCTS: list[Product] = [
    # 패션·스타일 (착용 피팅)
    Product(id=0, brand="maxbone", name="스키 니트 점퍼", price=98000, fit=96, category="fashion", species="dog", fittable=True,
            image="/static/products/0.jpg", ref_image="/static/products/0.jpg",
            url="https://www.maxbone.com/products/ski-jumper",
            sizes=["XS", "S", "M", "L", "XL"]),
    Product(id=1, brand="Ruffwear", name="프론트 레인지 하네스", price=89000, fit=93, category="fashion", species="dog", fittable=True,
            image="/static/products/1.png", ref_image="/static/products/1.png",
            url="https://ruffwear.com/products/front-range-everyday-dog-harness",
            sizes=["XS", "S", "M", "L", "XL"]),
    Product(id=2, brand="Little Beast", name="빅 블랙 퍼퍼 재킷", price=112000, fit=94, category="fashion", species="dog", fittable=True,
            image="/static/products/2.jpg", ref_image="/static/products/2.jpg",
            url="https://littlebeast.co/products/the-super-duper-reversible-parka-vest-black",
            sizes=["XS", "S", "M", "L", "XL"]),
    Product(id=3, brand="maxbone", name="스트레인저 씽스 시그니처 후디", price=92000, fit=92, category="fashion", species="dog", fittable=True,
            image="/static/products/3.jpg", ref_image="/static/products/3.jpg",
            url="https://www.maxbone.com/products/stranger-things-x-maxbone-hoodie",
            sizes=["XS", "S", "M", "L", "XL"]),
    Product(id=4, brand="Ruffwear", name="파우더 하운드 윈터 재킷", price=119000, fit=90, category="fashion", species="dog", fittable=True,
            image="/static/products/4.png", ref_image="/static/products/4.png",
            url="https://ruffwear.com/products/powder-hound-jacket",
            sizes=["XS", "S", "M", "L", "XL"]),
    Product(id=5, brand="Little Beast", name="다크 앤 스토미 스트라이프 원지", price=72000, fit=88, category="fashion", species="cat", fittable=True,
            image="/static/products/5.jpg", ref_image="/static/products/5.jpg",
            url="https://littlebeast.co/products/dark-and-stormy-onesie",
            sizes=["XS", "S", "M", "L", "XL"]),
    # 데일리케어
    Product(id=6, brand="earthbath", name="오트밀 & 알로에 저자극 샴푸 473ml", price=32000, fit=91, category="care", species="all", fittable=False,
            image="/static/products/6.png",
            url="https://earthbath.com/products/oatmeal-aloe-shampoo-fragrance-free"),
    Product(id=7, brand="Greenies", name="오리지널 덴탈 트릿 레귤러 27개입", price=56000, fit=87, category="care", species="dog", fittable=False,
            image="/static/products/7.png",
            url="https://www.greenies.com/products/treats/adult-dental-dog-treats-regular-size-original"),
    Product(id=8, brand="Open Farm", name="굿것 자연산 연어 키블 1.8kg", price=55000, fit=95, category="care", species="dog", fittable=False,
            image="/static/products/8.png",
            url="https://openfarmpet.com/products/goodgut-wild-caught-salmon-dog-kibble"),
    Product(id=9, brand="PureBites", name="닭가슴살 동결건조 트릿", price=12000, fit=90, category="care", species="dog", fittable=False,
            image="/static/products/9.png",
            url="https://purebites.com/products/chicken-freeze-dried-dog-treats"),
    # 액티브·아웃도어
    Product(id=10, brand="Ruffwear", name="프론트 레인지 리드줄", price=42000, fit=89, category="active", species="dog", fittable=False,
            image="/static/products/10.png",
            url="https://ruffwear.com/products/front-range-lightweight-dog-leash"),
    Product(id=11, brand="ibiyaya", name="트라보이스 3-in-1 폴딩 유모차 XL", price=320000, fit=92, category="active", species="all", fittable=True,
            image="/static/products/11.jpg",
            url="https://us.ibiyaya.com/products/ibiyaya%C2%AE-essential-travois-tri-fold-pet-travel-system-xl-pet-stroller-with-detachable-carrier"),
    Product(id=12, brand="Outward Hound", name="하이드 어 스쿼럴 노즈워크 토이", price=24000, fit=88, category="active", species="dog", fittable=False,
            image="/static/products/12.jpg",
            url="https://outwardhound.com/hide-a-squirrel-plush-puzzle-toy/"),
    # 헬스·웰니스
    Product(id=13, brand="Zesty Paws", name="그린립 홍합 힙&조인트 츄 90정", price=33000, fit=93, category="wellness", species="dog", fittable=False,
            image="/static/products/13.png",
            url="https://zestypaws.com/products/green-lipped-mussel-bites"),
    Product(id=14, brand="earthbath", name="시어버터 보습 스프레이", price=25000, fit=86, category="wellness", species="all", fittable=False,
            image="/static/products/14.png",
            url="https://earthbath.com/products/shea-butter-spray"),
    # 홈·인테리어 (배치 피팅)
    Product(id=15, brand="Catit", name="베스퍼 하이베이스 캣타워", price=235000, fit=94, category="home", species="cat", fittable=True,
            image="/static/products/15.jpg",
            url="https://www.catit.com/help-advice/furniture/vesper-high-base/"),
    Product(id=16, brand="MEOWFIA", name="프리미엄 펠트 캣 케이브", price=78000, fit=90, category="home", species="cat", fittable=True,
            image="/static/products/16.jpg",
            url="https://meowfia.us/products/premium-felt-cat-bed-cave-handmade-100-merino-wool-bed-for-cats-and-kittens"),
    Product(id=17, brand="Catit", name="플라워 급수기 3L", price=49000, fit=88, category="home", species="cat", fittable=False,
            image="/static/products/17.jpg",
            url="https://www.catit.com/products/drinking-fountains/flower-fountain/"),
]

PRODUCTS_BY_ID = {p.id: p for p in PRODUCTS}
