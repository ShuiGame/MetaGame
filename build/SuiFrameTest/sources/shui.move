module shui_module::shui {
    use std::option::{Self};
    use sui::coin::{Self, Coin, TreasuryCap, destroy_zero};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use std::vector::{Self};
    use std::string;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::pay;
    use sui::url;
    use sui::table::{Self, Table};
    use shui_module::race::{Self};
    use shui_module::level::{Self};
    use shui_module::gift::{Self};
    use shui_module::avatar::{Self};
    use shui_module::roles::{Self, RuleInfo};

    friend shui_module::airdrop;    

    const TYPE_FOUNDER:u64 = 0;
    const TYPE_CO_FOUNDER:u64 = 1;
    const TYPE_ENGINE_TEAM:u64 = 2;
    const TYPE_TECH_TEAM:u64 = 3;
    const TYPE_PROMOTE_TEAM:u64 = 4;
    const TYPE_PARTNER:u64 = 5;
    const TYPE_ANGLE_INVEST:u64 = 6;
    const TYPE_PUBLIC:u64 = 7;
    const TYPE_META_VIP:u64 = 8;
    const SHUI_ICON_URL:vector<u8> = b"https://nftstorage.link/ipfs/bafybeieqqos2upvmmxzmauv6cf53ddegpjc5zkrvbpriz7iajamcxikv4y";

    const ERR_CHARACTOR_CREATED:u64 = 0x001;
    const ERR_BINDED:u64 = 0x002;
    const ERR_UNBINDED:u64 = 0x003;
    const ERR_NO_PERMISSION:u64 = 0x004;
    const ERR_NOT_IN_WHITELIST:u64 = 0x005;
    const EXCEED_SWAP_LIMIT:u64 = 0x006;
    const ERR_BALANCE_NOT_ENOUGH:u64 = 0x007;
    const ERR_ALREADY_BIND:u64 = 0x008;
    const ERR_SWAP_MIN_ONE_SUI:u64 = 0x009;
    const ERR_INVALID_TYPE:u64 = 0x010;
    const ERR_META_HAS_CREATED:u64 = 0x011;

    const TOTAL_SUPPLY: u64 = 2_100_000_000;
    const FOUNDATION_RESERVE:u64 = 50_000_000;
    const DAO_RESERVE:u64 = 50_000_000;
    const GAME_RESERVE:u64 = 1_200_000_000;
    const EXCHANGE_RESERVE:u64 = 100_000_000;
    const AMOUNT_DECIMAL:u64 = 1_000_000_000;

    const AIRDROP_AMOUNT:u64 = 300_000_000;

    struct SHUI has drop {}
    struct Global has key {
        id: UID,
        supply: u64,

        // split by balance
        balance_SUI: Balance<SUI>,
        balance_SHUI: Balance<SHUI>,
        creator: address,

        founder_whitelist: Table<address, u64>,
        co_founder_whitelist: Table<address, u64>,
        game_engine_team_whitelist: Table<address, u64>,
        tech_whitelist: Table<address, u64>,
        promote_whitelist: Table<address, u64>,
        partner_whitelist: Table<address, u64>,
        angle_invest_whitelist: Table<address, u64>,
        meta_id_whitelist: Table<address, u64>,
        swaped_sui:u64,
        swaped_shui:u64,

        metauser_list: Table<address, u64>,
    }

    struct Inscription has key {
        id:UID,
        name: string::String,
        gender: string::String,
        avatar: avatar::Avatar,
        race: race::Race,
        level: level::Level,
        gift: gift::Gift,
    }

    fun init(witness: SHUI, ctx: &mut TxContext) {
        let (adminCap, metadata) = coin::create_currency(witness, 
            9,
            b"SHUI",
            b"SHUI",
            b"SHUI token",
            option::some(url::new_unsafe_from_bytes(SHUI_ICON_URL)),
            ctx);
        transfer::public_freeze_object(metadata);
        let global = Global {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            supply: TOTAL_SUPPLY,
            balance_SUI: balance::zero(),
            balance_SHUI: balance::zero(),

            founder_whitelist: table::new<address, u64>(ctx),
            co_founder_whitelist: table::new<address, u64>(ctx),
            game_engine_team_whitelist: table::new<address, u64>(ctx),
            tech_whitelist: table::new<address, u64>(ctx),
            promote_whitelist:  table::new<address, u64>(ctx),
            partner_whitelist: table::new<address, u64>(ctx),
            angle_invest_whitelist: table::new<address, u64>(ctx),
            meta_id_whitelist: table::new<address, u64>(ctx),
            swaped_sui:0,
            swaped_shui:0,
            metauser_list: table::new<address, u64>(ctx),
        };
        let total_shui = mint(&mut adminCap, TOTAL_SUPPLY * AMOUNT_DECIMAL, ctx);
        transfer::public_transfer(adminCap, tx_context::sender(ctx));
        let balance = coin::into_balance<SHUI>(
            total_shui
        );
        balance::join(&mut global.balance_SHUI, balance);

        // transfer ther reserve shui to dao and foundation account;
        transfer_to_reserve(&mut global, @foundation_reserve_wallet, FOUNDATION_RESERVE * AMOUNT_DECIMAL, ctx);
        transfer_to_reserve(&mut global, @dao_reserve_wallet, DAO_RESERVE * AMOUNT_DECIMAL, ctx);
        transfer_to_reserve(&mut global, @game_reserve_wallet, GAME_RESERVE * AMOUNT_DECIMAL, ctx);
        transfer_to_reserve(&mut global, @exchange_reserve_wallet, EXCHANGE_RESERVE * AMOUNT_DECIMAL, ctx);
        // transfer_to_reserve(&mut global, @airdrop_reserve_contract, ctx);
        transfer::share_object(global);
    }

    public fun new_empty_charactor(ctx: &mut TxContext):Inscription {
        Inscription{
            id:object::new(ctx),
            name:string::utf8(b""),
            gender: string::utf8(b""),
            avatar: avatar::none(),
            race: race::none(),
            level: level::new_level(),
            gift: gift::none(),
        }
    }

    public entry fun change_gift(charactor:&mut Inscription, gift:string::String) {
        charactor.gift = gift::new_gift(gift);
    }

    public fun mint(treasuryCap:&mut TreasuryCap<SHUI>, amount:u64, ctx:&mut TxContext) : Coin<SHUI>{
        coin::mint(treasuryCap, amount, ctx)
    }

    fun transfer_to_reserve(global: &mut Global, recepient:address, amount:u64, ctx:&mut TxContext) {
        let airdrop_balance = balance::split(&mut global.balance_SHUI, amount);
        let shui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(shui, recepient);
    }

    public(friend) entry fun airdrop_claim(global: &mut Global, amount:u64, ctx:&mut TxContext) {
        let airdrop_balance = balance::split(&mut global.balance_SHUI, amount);
        let shui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(shui, tx_context::sender(ctx));
    }

    public entry fun swap<T> (global: &mut Global, rule_info: &RuleInfo, sui_pay_amount:u64, coins:vector<Coin<SUI>>, type:u64, ctx:&mut TxContext) {
        assert!(type >= TYPE_FOUNDER && type <= TYPE_META_VIP, ERR_INVALID_TYPE);
        let ratio = roles::get_ratio_by_type(rule_info, type);
        let limit = roles::get_swap_num_limit_by_type(rule_info, type);
        let recepient = tx_context::sender(ctx);
        let whitelist_table;
        if (type == TYPE_FOUNDER) {
            whitelist_table = &mut global.founder_whitelist;
        } else if (type == TYPE_CO_FOUNDER) {
            whitelist_table = &mut global.co_founder_whitelist;
        } else if (type == TYPE_ENGINE_TEAM) {
            whitelist_table = &mut global.game_engine_team_whitelist;
        } else if (type == TYPE_TECH_TEAM) {
            whitelist_table = &mut global.tech_whitelist;
        } else if (type == TYPE_PROMOTE_TEAM) {
            whitelist_table = &mut global.promote_whitelist;
        } else if (type == TYPE_PARTNER) {
            whitelist_table = &mut global.partner_whitelist;
        } else {
            whitelist_table = &mut global.angle_invest_whitelist;
        };
        let shui_to_be_swap:u64 = sui_pay_amount * ratio;
        if (type != TYPE_PUBLIC) {
            assert!(table::contains(whitelist_table, tx_context::sender(ctx)), ERR_NOT_IN_WHITELIST);
            assert!(has_swap_amount(whitelist_table, shui_to_be_swap, recepient), EXCEED_SWAP_LIMIT);
        };
        global.swaped_shui = global.swaped_shui + shui_to_be_swap * AMOUNT_DECIMAL;
        global.swaped_sui = global.swaped_sui + sui_pay_amount * AMOUNT_DECIMAL;
        let account = tx_context::sender(ctx);
        let merged_coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut merged_coin, coins);
        assert!(coin::value(&merged_coin) >= 1, ERR_SWAP_MIN_ONE_SUI);
        assert!(sui_pay_amount <= limit, ERR_SWAP_MIN_ONE_SUI);
        let balance = coin::into_balance<SUI>(
            coin::split<SUI>(&mut merged_coin, sui_pay_amount * AMOUNT_DECIMAL, ctx)
        );
        balance::join(&mut global.balance_SUI, balance);
        if (coin::value(&merged_coin) > 0) {
            transfer::public_transfer(merged_coin, account)
        } else {
            destroy_zero(merged_coin)
        };
        let shui_balance = balance::split(&mut global.balance_SHUI, shui_to_be_swap * AMOUNT_DECIMAL);
        let shui = coin::from_balance(shui_balance, ctx);
        transfer::public_transfer(shui, account);
        if (type != TYPE_PUBLIC) {
            record_swaped_amount(whitelist_table, sui_pay_amount * ratio, recepient);
        };
    }

    public entry fun burn<T>(treasury: &mut TreasuryCap<SHUI>, coin: Coin<SHUI>) {
        coin::burn(treasury, coin);
    }

    public fun add_whitelist_by_type(global: &mut Global, ruleInfo:&RuleInfo, account: address, type:u64, ctx: &mut TxContext) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        assert!(type >= TYPE_FOUNDER && type <= TYPE_META_VIP, ERR_INVALID_TYPE);
        let reserve = roles::get_per_reserve_by_type(ruleInfo, type);
        let whitelist_table;
         if (type == TYPE_FOUNDER) {
            whitelist_table = &mut global.founder_whitelist;
        } else if (type == TYPE_CO_FOUNDER) {
            whitelist_table = &mut global.co_founder_whitelist;
        } else if (type == TYPE_ENGINE_TEAM) {
            whitelist_table = &mut global.game_engine_team_whitelist;
        } else if (type == TYPE_TECH_TEAM) {
            whitelist_table = &mut global.tech_whitelist;
        } else if (type == TYPE_PROMOTE_TEAM) {
            whitelist_table = &mut global.promote_whitelist;
        } else if (type == TYPE_PARTNER) {
            whitelist_table = &mut global.partner_whitelist;
        } else if (type == TYPE_ANGLE_INVEST) {
            whitelist_table = &mut global.angle_invest_whitelist;
        } else if (type == TYPE_META_VIP) {
            whitelist_table = &mut global.meta_id_whitelist;
        } else {
            // never reach mannually
            whitelist_table = &mut global.meta_id_whitelist;
        };
        assert!(table::length(whitelist_table) == 0, 1);
        table::add(whitelist_table, account, reserve);
    }

    public fun add_whitelists_by_type(global: &mut Global, ruleInfo:&RuleInfo, whitelist: vector<address>, type:u64, ctx: &mut TxContext) {
        assert!(global.creator == tx_context::sender(ctx), ERR_NO_PERMISSION);
        assert!(type >= TYPE_FOUNDER && type <= TYPE_META_VIP, ERR_INVALID_TYPE);
        let reserve = roles::get_per_reserve_by_type(ruleInfo, type);
        let whitelist_table;
         if (type == TYPE_FOUNDER) {
            whitelist_table = &mut global.founder_whitelist;
        } else if (type == TYPE_CO_FOUNDER) {
            whitelist_table = &mut global.co_founder_whitelist;
        } else if (type == TYPE_ENGINE_TEAM) {
            whitelist_table = &mut global.game_engine_team_whitelist;
        } else if (type == TYPE_TECH_TEAM) {
            whitelist_table = &mut global.tech_whitelist;
        } else if (type == TYPE_PROMOTE_TEAM) {
            whitelist_table = &mut global.promote_whitelist;
        } else if (type == TYPE_PARTNER) {
            whitelist_table = &mut global.partner_whitelist;
        } else if (type == TYPE_META_VIP) {
            whitelist_table = &mut global.meta_id_whitelist;
        } else {
            // never reach mannually
            whitelist_table = &mut global.meta_id_whitelist;
        };
        let (i, len) = (0u64, vector::length(&whitelist));
        while (i < len) {
            let account = vector::pop_back(&mut whitelist);
            table::add(whitelist_table, account, reserve);
            i = i + 1
        };
    }

    fun record_swaped_amount(table: &mut Table<address, u64>, amount_culmulate:u64, recepient: address) {
        let value:&mut u64 = table::borrow_mut(table, recepient);
        *value = *value - amount_culmulate;
    }

    fun has_swap_amount(table: &Table<address, u64>, amount_to_swap:u64, recepient: address): bool {
       let left_amount = *table::borrow(table, recepient);
       left_amount >= amount_to_swap
    }

    public entry fun withdraw_sui(global: &mut Global, amount:u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);
        let airdrop_balance = balance::split(&mut global.balance_SUI, amount);
        let sui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(sui, tx_context::sender(ctx));
    }

    public entry fun withdraw_shui(global: &mut Global, amount:u64, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);

        let airdrop_balance = balance::split(&mut global.balance_SHUI, amount);
        let shui = coin::from_balance(airdrop_balance, ctx);
        transfer::public_transfer(shui, tx_context::sender(ctx));
    }

    public fun get_swaped_sui(global: &Global) :u64 {
        global.swaped_sui
    }

    public fun get_swaped_shui(global: &Global) :u64 {
        global.swaped_shui
    }

    public(friend) fun extract_airdrop_balance(global: &mut Global, ctx: &mut TxContext) : balance::Balance<SHUI> {
        assert!(tx_context::sender(ctx) == global.creator, ERR_NO_PERMISSION);
        balance::split(&mut global.balance_SHUI, AIRDROP_AMOUNT * AMOUNT_DECIMAL)
    }
}