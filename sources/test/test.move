// Copyright 2023 ComingChat Authors. Licensed under Apache-2.0 License.
#[test_only]
module shui_module::airdrop_test {
    use std::vector;
    use std::string;
    use sui::clock;
    use std::debug::print;
    use sui::coin::{Self, Coin};
    use sui::test_scenario::{
        Scenario, next_tx, begin, end, ctx, take_shared, return_shared, take_from_sender,return_to_sender,take_from_address,
        next_epoch
    };
    use sui::tx_context;
    use sui::pay;
    use shui_module::items::{Self};
    use shui_module::shui::{Self};
    use shui_module::metaIdentity::{Self};
    use shui_module::airdrop::{Self};
    use shui_module::founder_team_reserve::{Self};
    use shui_module::swap::{Self};
    use shui_module::tree_of_life::{Self};
    use shui_module::crypto::{Self};
    use shui_module::boat_ticket::{Self};
    use shui_module::market::{Self};
    use sui::object::{Self};
    use sui::kiosk::{Self};

    use sui::hex::{Self};

    const AMOUNT_DECIMAL:u64 = 1_000_000_000;
    const DAY_IN_MS: u64 = 86_400_000;
    const HOUR_IN_MS: u64 = 3_600_000;
    const START:u64 = 80000;

    // utilities
    fun scenario(): Scenario { begin(@account) }

    fun claim_airdrop(test: &mut Scenario, clock:&clock::Clock) {
        let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
        let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        airdrop::claim_airdrop(&mut airdropGlobal, &meta, clock, ctx(test));
        return_to_sender(test, meta);
        return_shared(airdropGlobal);
    }

    fun water_down(test: &mut Scenario, user:address, clock:&clock::Clock) {
        let treeGlobal = take_shared<tree_of_life::TreeGlobal>(test);
        let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        let coin = take_from_address<Coin<shui::SHUI>>(test, user);
        let coins = vector::empty<Coin<shui::SHUI>>();
        vector::push_back(&mut coins, coin);
        tree_of_life::water_down(&mut treeGlobal, &mut meta, coins, clock, ctx(test));
        // let exp = tree_of_life::get_water_down_person_exp(&treeGlobal, user);
        // print(&string::utf8(b"exp:"));
        // print(&exp);
        return_to_sender(test, meta);
        return_shared(treeGlobal);
    }

    fun print_items(itemGlobal: &items::ItemGlobal, test: &mut Scenario) {
        let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        let items_info = metaIdentity::get_items_info(&meta, itemGlobal);
        print(&items_info);
        return_to_sender(test, meta);
    }

    fun print_balance(test: &mut Scenario, user:address) {
        let coin = take_from_address<Coin<shui::SHUI>>(test, user);
        let value = coin::value(&coin);
        print(&string::utf8(b"account shui:"));
        print(&value);
        pay::keep(coin, ctx(test));
    }

    // fun print_ids(test: &Scenario) {
    //     let ids = ids_for_sender<Coin<shui::SHUI>>(test);
    //     print(&ids);
    // }

    // #[test]
    fun test_crypto() {
        let scenario = scenario();
        let test = &mut scenario;
        let admin = @account;

        // init package
        next_tx(test, admin);
        {
            let res = crypto::test_ecds();
            print(&string::utf8(b"test:"));
            print(&res);
            // print(hex::decode(b"This is a test of the tsunami alert system."));
        };
        end(scenario);
    }

    #[test]
    fun test_market() {
        let scenario = scenario();
        let test = &mut scenario;
        let admin = @account;

        next_tx(test, admin);
        {
            boat_ticket::init_for_test(ctx(test));
        };

        // init package
        next_tx(test, admin);
        {
            let ticketGlobal = take_shared<boat_ticket::BoatTicketGlobal>(test);
            boat_ticket::claim_ticket(&mut ticketGlobal, ctx(test));
            next_epoch(test, admin);
            let ticket = take_from_sender<boat_ticket::BoatTicket>(test);
            let addr = object::id_address(&ticket);

            market::place_and_list_nft(ticket, 10, ctx(test));
            next_epoch(test, admin);

            let kiosk = take_from_sender<kiosk::Kiosk>(test);
            let cap = take_from_sender<kiosk::KioskOwnerCap>(test);
            market::take_and_transfer(&mut kiosk, &cap, addr, ctx(test));
            return_to_sender(test, kiosk);
            return_to_sender(test, cap);

            next_epoch(test, admin);

            let kiosk = take_from_sender<kiosk::Kiosk>(test);
            let cap = take_from_sender<kiosk::KioskOwnerCap>(test);
            market::close_and_withdraw(kiosk, cap, ctx(test));
            return_shared(ticketGlobal);
        };

        end(scenario);
    }

    // #[test]
    fun test_init() {
        let scenario = scenario();
        let test = &mut scenario;
        let admin = @account;
        let test_user = @0xaefddfe2f5ab51c5903146115582b7e717cad239926c8fa0fb370d724a626f84;
        let clock = clock::create_for_testing(ctx(test));

        // init package
        next_tx(test, admin);
        {
            shui::init_for_test(test);
            metaIdentity::init_for_test(ctx(test));
            airdrop::init_for_test(ctx(test));
            swap::init_for_test(ctx(test));
            founder_team_reserve::init_for_test(ctx(test));
            tree_of_life::init_for_test(ctx(test));
            items::init_for_test(ctx(test));
        };

        // funds split
        next_tx(test, admin);
        {
            let shuiGlobal = take_shared<shui::Global>(test);

            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let reserveGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let swapGlobal = take_shared<swap::SwapGlobal>(test);

            airdrop::init_funds_from_main_contract(&mut airdropGlobal, &mut shuiGlobal, ctx(test));
            founder_team_reserve::init_funds_from_main_contract(&mut reserveGlobal, &mut shuiGlobal, ctx(test));
            swap::init_funds_from_main_contract(&mut swapGlobal, &mut shuiGlobal, ctx(test));

            return_shared(shuiGlobal);
            return_shared(airdropGlobal);
            return_shared(reserveGlobal);
            return_shared(swapGlobal);
        };
        
        // register meta
        next_tx(test, admin);
        {
            let global = take_shared<metaIdentity::MetaInfoGlobal>(test);
            metaIdentity::mintMeta(
                &mut global,
                string::utf8(b"sean"),
                string::utf8(b"13262272231"),
                string::utf8(b"448651346@qq.com"),
                test_user,
                ctx(test)
            );
            return_shared(global)
        };

        // start clock
        next_tx(test, admin);
        {
            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let timeCap = take_from_sender<airdrop::TimeCap>(test);
            let clock = clock::create_for_testing(ctx(test));
            clock::increment_for_testing(&mut clock, START);
            airdrop::start_timing(&mut airdropGlobal, timeCap, &clock);
            return_shared(airdropGlobal);
            clock::destroy_for_testing(clock);
        };

        // airdrop test
        next_tx(test, test_user);
        {
            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let value = airdrop::get_total_shui_balance(&mut airdropGlobal);
            print(&string::utf8(b"airdrop pool:"));
            print(&value);
            return_shared(airdropGlobal);
            next_epoch(test, test_user);
            clock::increment_for_testing(&mut clock, 1 * DAY_IN_MS);
            let i = 0;
            while (i < 100) {
                claim_airdrop(test, &clock);
                next_epoch(test, test_user);
                clock::increment_for_testing(&mut clock, 1 * DAY_IN_MS + 1);
                i = i + 1;
            };
            print_balance(test, test_user);
        };

        // water down test
        next_tx(test, test_user);
        {
            let itemGlobal = take_shared<items::ItemGlobal>(test);
            let i = 0;
            while (i < 200) {
                clock::increment_for_testing(&mut clock, 8 * HOUR_IN_MS + 1);
                water_down(test, test_user, &clock);
                next_epoch(test, test_user);
                i = i + 1;
            };
            print_items(&itemGlobal, test);
            return_shared(itemGlobal);
        };

        // open fruits test
        next_tx(test, test_user);
        {
            let itemGlobal = take_shared<items::ItemGlobal>(test);
            tx_context::increment_epoch_timestamp(ctx(test), 4);
            let i = 0;
            let loop_num = 5;
            let days_min = loop_num * 3;
            print(&string::utf8(b"min_days:"));
            print(&days_min);
            while (i < loop_num) {
                let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
                tree_of_life::open_fruit(&mut meta, ctx(test));
                return_to_sender(test, meta);
                next_epoch(test, test_user);
                i = i + 1;
                next_epoch(test, test_user);
            };
            print_items(&itemGlobal, test);
            return_shared(itemGlobal);
        };

        // synthesis test
        next_tx(test, test_user);
        {
            // let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
            // tree_of_life::swap_fragment<tree_of_life::Fragment>(&mut meta, string::utf8(b"holy"));
            // return_to_sender(test, meta);
            // next_epoch(test, test_user);
            // print_items(test);
        };

        // founder_team_reserve start
        next_tx(test, admin);
        {
            let founderTeamGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let time_cap = take_from_sender<founder_team_reserve::TimeCap1>(test);
            founder_team_reserve::start_phase1(&mut founderTeamGlobal, time_cap, &clock);
            tx_context::increment_epoch_timestamp(ctx(test), 1);
            return_shared(founderTeamGlobal);
        };

        // set swap whitelist
        next_tx(test, admin);
        {
            let type = 0;
            let swapGlobal = take_shared<swap::SwapGlobal>(test);
            let msg = x"be379359ac6e9d0fc0b867f147f248f1c2d9fc019a9a708adfcbe15fc3130c18";
            let sig = x"91EEC3C09428D1E3ECF7DDD723E71A6E7108293FD7B0EB6AE2C796A84D8DF3AE09D6119EE5FE9016BC14847C3AF69130B4CE06534EA1A5EBB13142BFCA0A430C";
            swap::white_list_backup(&mut swapGlobal, &sig, &msg, ctx(test));
            return_shared(swapGlobal);
            next_epoch(test, admin);
        };

        // set founder team whitelist
        next_tx(test, admin);
        {
            let type = 0;
            let founderTeamGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let value = founder_team_reserve::get_total_shui_balance(&mut founderTeamGlobal);
            print(&string::utf8(b"reserve pool:"));
            print(&value);
            let whitelist = vector::empty();
            vector::push_back(&mut whitelist, test_user);
            founder_team_reserve::set_white_lists(&mut founderTeamGlobal, whitelist, type, ctx(test));
            return_shared(founderTeamGlobal);
            next_epoch(test, admin);
        };

        // reserve claim test
        clock::increment_for_testing(&mut clock, 1 * HOUR_IN_MS);
        next_tx(test, test_user);
        {
            let type = 0;
            let phase = 1;
            let founderTeamGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let cliamed = founder_team_reserve::claim_reserve(&mut founderTeamGlobal, &clock, type, phase, ctx(test));
            print(&cliamed);
            return_shared(founderTeamGlobal);
        };

        // reserve claim test2
        clock::increment_for_testing(&mut clock, 30 * DAY_IN_MS + 1);
        next_tx(test, test_user);
        {
            let type = 0;
            let phase = 1;
            let founderTeamGlobal = take_shared<founder_team_reserve::FounderTeamGlobal>(test);
            let cliamed = founder_team_reserve::claim_reserve(&mut founderTeamGlobal, &clock, type, phase, ctx(test));
            print(&cliamed);
            return_shared(founderTeamGlobal);
        };

        clock::destroy_for_testing(clock);
        end(scenario);
    }
}