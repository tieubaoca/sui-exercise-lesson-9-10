/// A flash loan that works for any Coin type
module lesson9::flash_lender {
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::balance::{Self, Supply, Balance};
    use sui::object::{Self,UID, ID};
    use sui::transfer;
    use sui::math;
    use sui::object_bag::{Self, ObjectBag};
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::pay;

    const EInsufficientFunds: u64 = 1;
    const EInvalidReceipt: u64 = 2;
    const EInvalidRepayment: u64 = 3;
    const EAdminOnly: u64 = 4;

    const FEE_DIVISOR: u64 = 1000;

    struct FlashLender<phantom T> has key {
        id: UID,
        /// Số lượng coin được phép vay
        to_lend: Balance<T>,
        fee: u64,
    }

    /// Đây là struct không có key và store, nên nó sẽ không được transfer và không được lưu trữ bền vững. và nó cũng không có drop nên cách duy nhất để xoá nó làm gọi hàm repay.
    /// Đây là cái chúng ta muốn cho một gói vay.
    struct Receipt<phantom T> {
        flash_lender_id: ID,
        repay_amount: u64
    }

    /// Một đối tượng truyền đạt đặc quyền rút tiền và gửi tiền vào
    /// trường hợp của `FlashLender` có ID `flash_lender_id`. Ban đầu được cấp cho người tạo của `FlashLender`
    /// và chỉ tồn tại một `AdminCap` duy nhất cho mỗi nhà cho vay.
    struct AdminCap has key, store {
        id: UID,
        flash_lender_id: ID,
    }

    fun init(
        ctx: &mut TxContext
    ) {}

    // === Creating a flash lender ===

    /// Tạo một đối tượng `FlashLender` chia sẻ làm cho `to_lend` có sẵn để vay
    /// Bất kỳ người vay nào sẽ cần trả lại số tiền đã vay và `fee` trước khi kết thúc giao dịch hiện tại.
    public fun new<T>(to_lend: Balance<T>, fee: u64, ctx: &mut TxContext): AdminCap {
        let flash_lender = FlashLender {
            id: object::new(ctx),
            to_lend: to_lend,
            fee: fee,
        };
        let admin_cap = AdminCap {
            id: object::new(ctx),
            flash_lender_id: object:: uid_to_inner(&flash_lender.id),
        };
        transfer::share_object(flash_lender);
        admin_cap
    }

    /// Giống như `new`, nhưng chuyển `AdminCap` cho người gửi giao dịch
    public entry fun create<T>(to_lend: Coin<T>, fee: u64, ctx: &mut TxContext) {
        let admin_cap = new(coin::into_balance<T>(to_lend), fee, ctx);
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

   /// Yêu cầu một khoản vay với `amount` từ `lender`. `Receipt<T>`
   /// đảm bảo rằng người vay sẽ gọi `repay(lender, ...)` sau này trong giao dịch này.
   /// Hủy bỏ nếu `amount` lớn hơn số tiền mà `lender` có sẵn để cho vay.
    public fun loan<T>(
        self: &mut FlashLender<T>, amount: u64, ctx: &mut TxContext
    ): (Coin<T>, Receipt<T>) {
        assert!(amount <= max_loan(self), EInsufficientFunds);
        let coin = coin::from_balance(
            balance::split(&mut self.to_lend, amount),
            ctx
        );
        let receipt = Receipt{
            flash_lender_id: object::uid_to_inner(&self.id),
            repay_amount: amount + amount * self.fee / FEE_DIVISOR
        };

        (coin, receipt)
    }

   /// Trả lại khoản vay được ghi lại bởi `receipt` cho `lender` với `payment`.
   /// Hủy bỏ nếu số tiền trả lại không chính xác hoặc `lender` không phải là `FlashLender` đã cấp khoản vay ban đầu.
    public fun repay<T>(self: &mut FlashLender<T>, payment: Coin<T>, receipt: Receipt<T>) {
        let Receipt<T>{
            flash_lender_id: flash_lender_id,
            repay_amount: repay_amount
        } = receipt;
        assert!(flash_lender_id == object:: uid_to_inner(&self.id), EInvalidReceipt);
        assert!(coin::value(&payment) == repay_amount, EInvalidRepayment);
        coin::put(&mut self.to_lend, payment);
    }

    /// Cho phép quản trị viên của `self` rút tiền.
    public fun withdraw<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, amount: u64, ctx: &mut TxContext): Coin<T> {
        check_admin(self, admin_cap);
        coin::from_balance(
            balance::split(&mut self.to_lend, amount),
            ctx
        )
    }

    public entry fun deposit<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, coin: Coin<T>) {
        // Chỉ có chủ sở hữu của `AdminCap` cho `self` mới có thể gửi tiền vào.
        check_admin(self, admin_cap);
        coin::put(&mut self.to_lend, coin);
    }

    /// Cho phép quản trị viên cập nhật phí cho `self`.
    public entry fun update_fee<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, new_fee: u64) {
        check_admin(self, admin_cap);
        self.fee = new_fee;
    }

    fun check_admin<T>(self: &FlashLender<T>, admin_cap: &AdminCap) {
        assert!(object::borrow_id(self) == &admin_cap.flash_lender_id, EAdminOnly);
    }


    /// Return the current fee for `self`
    public fun fee<T>(self: &FlashLender<T>): u64 {
        self.fee
    }

    /// Trả về số tiền tối đa có sẵn để mượn.
    public fun max_loan<T>(self: &FlashLender<T>): u64 {
        balance::value<T>(&self.to_lend)
    }

    /// Trả về số tiền mà người giữ `self` phải trả lại.
    public fun repay_amount<T>(self: &Receipt<T>): u64 {
        self.repay_amount
    }

    /// Trả về số tiền mà người giữ `self` phải trả lại.
    public fun flash_lender_id<T>(self: &Receipt<T>): ID {
        self.flash_lender_id
    }
}
