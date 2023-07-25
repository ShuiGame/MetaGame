module shui_module::airdrop {
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use shui_module::shui::{Self};
    use shui_module::metaIdentity::{Self, MetaIdentity};
    use sui::clock::{Self, Clock};
    use sui::table::{Self};

    const ERR_INVALID_PHASE:u64 = 0x001;
    const ERR_NO_PERMISSION:u64 = 0x002;
    const ERR_NOT_IN_WHITELIST:u64 = 0x003;
    const ERR_HAS_CLAIMED_IN_24HOUR:u64 = 0x004;
    const ERR_AIRDROP_NOT_START:u64 = 0x005;
    const ERR_HAS_CLAIMED:u64 = 0x006;
    const ERR_INACTIVE_META:u64 = 0x007;
    const ERR_EXCEED_DAILY_LIMIT:u64 = 0x008;

    const WHITELIST_AIRDROP_AMOUNT:u64 = 10_000;
    const EStillClose: u64 = 1;
    const DAY_IN_MS: u64 = 86_400_000;
    const AMOUNT_DECIMAL:u64 = 1_000_000;

    struct AirdropGlobal has key {
        id: UID,
        current_phase: u64,
        start: u64,
        creator: address,

        // address -> has claimed the airdrop
        reserve_claim_records_list: table::Table<address, bool>,
        // address -> last claim time
        daily_claim_records_list: table::Table<address, u64>,

        total_claim_amount: u64,
        culmulate_remain_amount: u64,

        now_days: u64,
        total_daily_claim_amount: u64,
    }

    struct TimeCap has key {
        id: UID,
    }

    fun init(ctx: &mut TxContext) {
        let global = AirdropGlobal {
            id: object::new(ctx),
            current_phase: 1,
            start: 0,
            creator: tx_context::sender(ctx),
            reserve_claim_records_list: table::new<address, bool>(ctx),
            daily_claim_records_list: table::new<address, u64>(ctx),
            total_claim_amount: 0,
            culmulate_remain_amount: 0,
            now_days: 0,
            total_daily_claim_amount: 0,
        };
        transfer::share_object(global);
        let time_cap = TimeCap {
            id: object::new(ctx)
        };
        transfer::transfer(time_cap, tx_context::sender(ctx));
    }

    fun get_per_amount_by_time(global: &AirdropGlobal, clock: &Clock):u64 {
        let phase = get_phase_by_time(global, clock);
        assert!(phase >= 1 && phase <= 5, ERR_INVALID_PHASE);
        (60 - phase * 10) * AMOUNT_DECIMAL
    }

    fun get_phase_by_time(info:&AirdropGlobal, clock: &Clock):u64 {
        let now = clock::timestamp_ms(clock);
        let diff = now - info.start;
        let phase = diff / DAY_IN_MS + 1;
        if (phase > 5) {
            phase = 5;
        };
        phase
    }

    fun record_claim_time(table: &mut table::Table<address, u64>, time:u64, recepient: address) {
        if (table::contains(table, recepient)) {
            let _ = table::remove(table, recepient);
        };
        table::add(table, recepient, time);
    }

    public entry fun claim_airdrop(info:&mut AirdropGlobal, meta: &metaIdentity::MetaIdentity, global: &mut shui::Global, clock:&Clock, ctx: &mut TxContext) {
        // metaId check
        assert!(metaIdentity::is_active(meta), ERR_INACTIVE_META);
        assert!(info.start > 0, ERR_AIRDROP_NOT_START);
        let now = clock::timestamp_ms(clock);
        let user = tx_context::sender(ctx);
        let amount = get_per_amount_by_time(info, clock);
        
        // 1
        let days = get_now_days(clock, info);

        // 1 000 000 
        let daily_limit = get_daily_limit(days);
        if (days > info.now_days) {
            info.now_days = days;
            info.total_daily_claim_amount = amount;
        } else {
            info.total_daily_claim_amount = info.total_daily_claim_amount + amount;
        };
        info.total_claim_amount = info.total_claim_amount + amount;

        // 0 < 1 000 000
        assert!(info.total_daily_claim_amount < daily_limit, ERR_EXCEED_DAILY_LIMIT);
        let last_claim_time = 0;
        if (table::contains(&info.daily_claim_records_list, user)) {
            last_claim_time = *table::borrow(&info.daily_claim_records_list, user);
        };

        // for test 86_400_000 <- 60_000
        assert!((now - last_claim_time) > 60_000, ERR_HAS_CLAIMED_IN_24HOUR);
        shui::airdrop_claim(global, amount, ctx);
        record_claim_time(&mut info.daily_claim_records_list, now, user)
    }

    public entry fun test01(info: &AirdropGlobal) {
        let daily_limit = get_daily_limit(1);
        assert!(info.total_daily_claim_amount < daily_limit, ERR_EXCEED_DAILY_LIMIT);
    }

    public entry fun test02(info: &AirdropGlobal) {
        assert!(info.total_daily_claim_amount < 1_000_000, ERR_EXCEED_DAILY_LIMIT);
    }

    public entry fun test03(clock:&Clock, info: &AirdropGlobal):u64 {
        let days = get_now_days(clock, info);
        let daily_limit = get_daily_limit(days);
        daily_limit
    }

    public entry fun claim_airdrop_whitelist(info:&mut AirdropGlobal, meta: &MetaIdentity, global: &mut shui::Global, ctx: &mut TxContext) {
        // todo:change whitelist to meta id check
        assert!(metaIdentity::is_active(meta), ERR_INACTIVE_META);
        assert!(metaIdentity::getMetaId(meta) < 20000, 1);
        let account = tx_context::sender(ctx);
        assert!(!table::contains(&info.reserve_claim_records_list, account), ERR_HAS_CLAIMED);
        shui::airdrop_claim(global, WHITELIST_AIRDROP_AMOUNT * AMOUNT_DECIMAL, ctx);
        table::add(&mut info.reserve_claim_records_list, account, true);
    }

    public entry fun start_timing(info:&mut AirdropGlobal, time_cap: TimeCap, clock_object: &Clock) {
        info.start = clock::timestamp_ms(clock_object);
        let TimeCap { id } = time_cap;
        object::delete(id);
    }

    public fun get_now(clock:&Clock):u64 {
        clock::timestamp_ms(clock)
    }

    public fun get_now_days(clock:&Clock, info: &AirdropGlobal):u64 {
        let time_diff = clock::timestamp_ms(clock) - info.start;
        time_diff / DAY_IN_MS + 1
    }

    public entry fun get_total_claim_amount(info: &AirdropGlobal):u64 {
        info.total_claim_amount
    }

    public entry fun get_total_daily_claim_amount(info: &AirdropGlobal):u64 {
        info.total_daily_claim_amount
    }

    public entry fun get_daily_remain_amount(clock:&Clock, info: &AirdropGlobal):u64 {
        let time_dif = clock::timestamp_ms(clock) - info.start;
        let days = time_dif / DAY_IN_MS;
        get_daily_limit(days) - info.total_daily_claim_amount
    }

    public entry fun get_daily_limit(days:u64) :u64 {
        if (days == 120) {
            AMOUNT_DECIMAL
        } else {
            (days / 30 + 1) * AMOUNT_DECIMAL
        }
    }

    public entry fun get_culmulate_remain_amount(clock:&Clock, info: &AirdropGlobal):u64 {
        assert!(info.start > 0, ERR_AIRDROP_NOT_START);
        let time_dif = clock::timestamp_ms(clock) - info.start;
        let days = time_dif / DAY_IN_MS;
        if (days <= 30) {
            days * AMOUNT_DECIMAL - info.total_claim_amount
        } else if (days <= 60) {
            (30 + days * 2) * AMOUNT_DECIMAL - info.total_claim_amount
        } else if (days <= 90) {
            (90 + days * 3) * AMOUNT_DECIMAL - info.total_claim_amount
        } else if (days <= 120) {
            (180 + days * 4) * AMOUNT_DECIMAL - info.total_claim_amount
        } else {
            (300 + days) * AMOUNT_DECIMAL - info.total_claim_amount
        }
    }
}