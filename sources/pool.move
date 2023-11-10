/// A flash loan that works for any Coin type
module lesson9::flash_lender {
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

    // === Creating a flash lender ===

    /// Tạo một đối tượng `FlashLender` chia sẻ làm cho `to_lend` có sẵn để vay
    /// Bất kỳ người vay nào sẽ cần trả lại số tiền đã vay và `fee` trước khi kết thúc giao dịch hiện tại.
    public fun new<T>(to_lend: Balance<T>, fee: u64, ctx: &mut TxContext): AdminCap {}

    /// Giống như `new`, nhưng chuyển `AdminCap` cho người gửi giao dịch
    public entry fun create<T>(to_lend: Coin<T>, fee: u64, ctx: &mut TxContext) {}

   /// Yêu cầu một khoản vay với `amount` từ `lender`. `Receipt<T>`
   /// đảm bảo rằng người vay sẽ gọi `repay(lender, ...)` sau này trong giao dịch này.
   /// Hủy bỏ nếu `amount` lớn hơn số tiền mà `lender` có sẵn để cho vay.
    public fun loan<T>(
        self: &mut FlashLender<T>, amount: u64, ctx: &mut TxContext
    ): (Coin<T>, Receipt<T>) {
    }

   /// Trả lại khoản vay được ghi lại bởi `receipt` cho `lender` với `payment`.
   /// Hủy bỏ nếu số tiền trả lại không chính xác hoặc `lender` không phải là `FlashLender` đã cấp khoản vay ban đầu.
    public fun repay<T>(self: &mut FlashLender<T>, payment: Coin<T>, receipt: Receipt<T>) {}

    /// Cho phép quản trị viên của `self` rút tiền.
    public fun withdraw<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, amount: u64, ctx: &mut TxContext): Coin<T> {}

    public entry fun deposit<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, coin: Coin<T>) {
        // Chỉ có chủ sở hữu của `AdminCap` cho `self` mới có thể gửi tiền vào.
    }

    /// Cho phép quản trị viên cập nhật phí cho `self`.
    public entry fun update_fee<T>(self: &mut FlashLender<T>, admin_cap: &AdminCap, new_fee: u64) {}

    fun check_admin<T>(self: &FlashLender<T>, admin_cap: &AdminCap) {
        assert!(object::borrow_id(self) == &admin_cap.flash_lender_id, EAdminOnly);
    }


    /// Return the current fee for `self`
    public fun fee<T>(self: &FlashLender<T>): u64 {}

    /// Trả về số tiền tối đa có sẵn để mượn.
    public fun max_loan<T>(self: &FlashLender<T>): u64 {}

    /// Trả về số tiền mà người giữ `self` phải trả lại.
    public fun repay_amount<T>(self: &Receipt<T>): u64 {}

    /// Trả về số tiền mà người giữ `self` phải trả lại.
    public fun flash_lender_id<T>(self: &Receipt<T>): ID {}
}
