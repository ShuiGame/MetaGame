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
    use shui_module::shui::{Self};
    use shui_module::metaIdentity::{Self};
    use shui_module::airdrop::{Self};
    use shui_module::founder_team_reserve::{Self};
    use shui_module::swap::{Self};
    use shui_module::tree_of_life::{Self};

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

    fun print_items(test: &mut Scenario) {
        let meta = take_from_sender<metaIdentity::MetaIdentity>(test);
        let items_info = metaIdentity::get_items_info(&meta);
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

    #[test]
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
        };

        // funds split
        next_tx(test, admin);
        {
            let airdropGlobal = take_shared<airdrop::AirdropGlobal>(test);
            let shuiGlobal = take_shared<shui::Global>(test);
            airdrop::init_funds_from_main_contract(&mut airdropGlobal, &mut shuiGlobal, ctx(test));
            airdrop::init_funds_from_main_contract(&mut airdropGlobal, &mut shuiGlobal, ctx(test));
            return_shared(airdropGlobal);
            return_shared(shuiGlobal);
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
            let i = 0;
            while (i < 200) {
                clock::increment_for_testing(&mut clock, 8 * HOUR_IN_MS + 1);
                water_down(test, test_user, &clock);
                next_epoch(test, test_user);
                i = i + 1;
            };
            // print_items(test);
        };

        // open fruits test
        next_tx(test, test_user);
        {
            tx_context::increment_epoch_timestamp(ctx(test), 3);
            let random = tree_of_life::get_random_num(0, 2000, ctx(test));
            print(&random);
            let i = 0;
            let loop_num = 20;
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
            print_items(test);
        };

        clock::destroy_for_testing(clock);
        end(scenario);
    }
}