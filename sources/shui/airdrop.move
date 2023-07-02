module shui_module::airdrop {
    use std::vector;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use shui_module::shui::{Self};
    use sui::clock::{Self, Clock};
    use sui::table::{Self};

    const ERR_INVALID_PHASE:u64 = 0x001;
    const ERR_NO_PERMISSION:u64 = 0x002;
    const ERR_NOT_IN_WHITELIST:u64 = 0x003;
    const ERR_HAS_CLAIMED_IN_24HOUR:u64 = 0x004;


    const WHITELIST_AIRDROP_AMOUNT:u64 = 10_000;
    const EStillClose: u64 = 1;
    const DAY_IN_MS: u64 = 86_400_000;

    struct AirdropGlobal has key {
        id: UID,
        current_phase: u64,
        start: u64,
        creator: address,
        reserve_whitelist: table::Table<address, u64>,
        // address -> last claim time
        claim_records_list: table::Table<address, u64>
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
            reserve_whitelist: table::new<address, u64>(ctx),
            claim_records_list: table::new<address, u64>(ctx),
        };
        transfer::share_object(global);
        let time_cap = TimeCap {
            id: object::new(ctx)
        };
        transfer::transfer(time_cap, tx_context::sender(ctx));
    }

    fun get_amount_by_time(global: &AirdropGlobal, clock: &Clock):u64 {
        let phase = get_phase_by_time(global, clock);
        assert!(phase >= 1 && phase <= 5, ERR_INVALID_PHASE);
        60 - phase * 10
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
        let _ = table::remove(table, recepient);
        table::add(table, recepient, time);
    }

    public entry fun claim_airdrop(info:&mut AirdropGlobal, global: &mut shui::Global, clock:&Clock, ctx: &mut TxContext) {
        let now = clock::timestamp_ms(clock);
        let user = tx_context::sender(ctx);
        let last_claim_time = *table::borrow(&info.claim_records_list, user);
        assert!((now - last_claim_time) > DAY_IN_MS, ERR_HAS_CLAIMED_IN_24HOUR);
        let amount = get_amount_by_time(info, clock);
        shui::airdrop_claim(global, amount, ctx);
        record_claim_time(&mut info.claim_records_list, now, user)
    }

    public entry fun claim_airdrop_whitelist(info:&mut AirdropGlobal, global: &mut shui::Global,ctx: &mut TxContext) {
        let account = tx_context::sender(ctx);
        assert!(table::contains(&info.reserve_whitelist, account), ERR_NOT_IN_WHITELIST);
        shui::airdrop_claim(global, WHITELIST_AIRDROP_AMOUNT, ctx);
        table::remove(&mut info.reserve_whitelist, account);
    }

    public entry fun start_timing(info:&mut AirdropGlobal, time_cap: TimeCap, clock_object: &Clock) {
        info.start = clock::timestamp_ms(clock_object);
        let TimeCap { id } = time_cap;
        object::delete(id);
    }

    public fun set_whitelists(info: &mut AirdropGlobal, whitelist: vector<address>, ctx: &mut TxContext) {
        assert!(info.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        let whitelist_table = &mut info.reserve_whitelist;
        let (i, len) = (0u64, vector::length(&whitelist));
        while (i < len) {
            let account = vector::pop_back(&mut whitelist);
            table::add(whitelist_table, account, 0);
            i = i + 1
        };
    }

    public fun add_whitelist(info: &mut AirdropGlobal, account:address, ctx: &mut TxContext) {
        assert!(info.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        table::add(&mut info.reserve_whitelist, account, 0);
    }
}