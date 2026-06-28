from .models import Product

# 더미 상품 (Claude Design 핸드오프 Sample Data). 실데이터 API 로 교체 예정.
PRODUCTS: list[Product] = [
    Product(id=0, brand="무무펫", name="코지 니트 스웨터", price=28000, fit=96),
    Product(id=1, brand="도그웨어", name="체크 하네스 세트", price=34000, fit=89),
    Product(id=2, brand="펫코", name="경량 패딩 베스트", price=42000, fit=94),
    Product(id=3, brand="모카독", name="데일리 후디", price=25000, fit=92),
    Product(id=4, brand="무무펫", name="윈터 울 코트", price=48000, fit=90),
    Product(id=5, brand="도그웨어", name="스트라이프 티셔츠", price=19000, fit=88),
]

PRODUCTS_BY_ID = {p.id: p for p in PRODUCTS}
