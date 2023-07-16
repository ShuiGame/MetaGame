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
        daily_claim_records_list: table::Table<address, u64>
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
        };
        transfer::share_object(global);
        let time_cap = TimeCap {
            id: object::new(ctx)
        };
        transfer::transfer(time_cap, tx_context::sender(ctx));
    }

    public entry fun get_amount_by_time(global: &AirdropGlobal, clock: &Clock):u64 {
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
        let last_claim_time = 0;
        if (table::contains(&info.daily_claim_records_list, user)) {
            last_claim_time = *table::borrow(&info.daily_claim_records_list, user);
        };

        // for test 86_400_000 <- 60_000
        assert!((now - last_claim_time) > 60_000, ERR_HAS_CLAIMED_IN_24HOUR);
        let amount = get_amount_by_time(info, clock);
        shui::airdrop_claim(global, amount, ctx);
        record_claim_time(&mut info.daily_claim_records_list, now, user)
    }

    public entry fun get_now(clock:&Clock):u64 {
        clock::timestamp_ms(clock)
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
}