%lang starknet

from src.constants import Color, Latent

@contract_interface
namespace IData {
    func get_data(idx: felt) -> (val: felt) {
    }
}

@contract_interface
namespace IMix {
    func mix(color1: Color, color2: Color, t: felt) -> (color: Color) {
    }

    func mix_multiple(color_len: felt, color: Color*, t_len: felt, t: felt*) -> (color: Color) {
    }

    func rgb_to_latent(color: Color) -> (latent: Latent) {
    }

    func latent_to_rgb(latent: Latent) -> (color: Color) {
    }

    func initializer(proxy_admin: felt, data_len: felt, data: felt*) {
    }

    func upgrade(new_implementation: felt) {
    }

    func upgrade_data(index: felt, contract_addr: felt) {
    }
}
