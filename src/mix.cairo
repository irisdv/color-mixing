%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import assert_not_zero, unsigned_div_rem
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bitwise import bitwise_and
from starkware.starknet.common.syscalls import get_caller_address

from src.utils.uint8_packed import view_get_element_at
from src.utils.math64x61 import Math64x61
from src.interface import IData
from src.constants import Color, Latent, LATENT_SIZE, MAX_DATA_PER_FELT, ONE, VAL_255, DATA_LENGTH
// from lib.openzeppelin.upgrades.library import Proxy

//
// Events
//
@event
func MixedColorMultiple(
    owner: felt, colors_len: felt, colors: Color*, t_len: felt, t: felt*, color: Color
) {
}

@event
func MixedColor(owner: felt, color1: Color, color2: Color, t: felt, res: Color) {
}

//
// Storage
//

@storage_var
func data_addr(index: felt) -> (val: felt) {
}

//
// Initializer
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    data_len: felt, data: felt*
) {
    assert_not_zero(data_len);
    set_up_data(data_len, data, 0);
    return ();
}

func set_up_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    data_len: felt, data: felt*, index: felt
) {
    if (data_len == 0) {
        return ();
    }
    data_addr.write(index, data[0]);
    return set_up_data(data_len - 1, data + 1, index + 1);
}

// @notice Mix 2 colors
// @param color1 - Color, 64x61 fixed point
// @param color2 - Color, 64x61 fixed point
// @param t - proportion, 64x61 fixed point
// @return res - Color, 64x61 fixed point
@external
func mix{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(color1: Color, color2: Color, t: felt) -> (color: Color) {
    alloc_locals;

    let (local latent1: Latent) = rgb_to_latent(color1);
    let (local latent2: Latent) = rgb_to_latent(color2);
    let (latent_mix: Latent) = lerp_latent(latent1, latent2, t);
    let (rgb: Color) = latent_to_rgb(latent_mix);

    let (caller) = get_caller_address();
    MixedColor.emit(caller, color1, color2, t, rgb);

    return (Color(rgb.r, rgb.g, rgb.b),);
}

// @notice Mix multiple colors
// @param colors - array of struct Color, 64x61 fixed point
// @param t - array of proportions, 64x61 fixed point
// @return res - Color, 64x61 fixed point
@external
func mix_multiple{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(color_len: felt, color: Color*, t_len: felt, t: felt*) -> (color: Color) {
    alloc_locals;

    let (local z: felt*) = alloc();
    rgb_to_latent_iter(color_len, color, 0, z);

    let (c0) = compute_w_proportions(0, t_len, t, color_len * 7, z, 0, 0);
    let (c1) = compute_w_proportions(1, t_len, t, color_len * 7, z, 0, 0);
    let (c2) = compute_w_proportions(2, t_len, t, color_len * 7, z, 0, 0);
    let (c3) = compute_w_proportions(3, t_len, t, color_len * 7, z, 0, 0);
    let (r) = compute_w_proportions(4, t_len, t, color_len * 7, z, 0, 0);
    let (g) = compute_w_proportions(5, t_len, t, color_len * 7, z, 0, 0);
    let (b) = compute_w_proportions(6, t_len, t, color_len * 7, z, 0, 0);

    let (rgb: Color) = latent_to_rgb(Latent(c0, c1, c2, c3, r, g, b));

    let (caller) = get_caller_address();
    MixedColorMultiple.emit(caller, color_len, color, t_len, t, rgb);

    return (rgb,);
}

// @notice Convert rgb to latent
// @param color - Color, 64x61 fixed point
// @return latent - Latent, 64x61 fixed point
@external
func rgb_to_latent{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(color: Color) -> (latent: Latent) {
    let lin_r = Math64x61.div(color.r, VAL_255);
    let lin_g = Math64x61.div(color.g, VAL_255);
    let lin_b = Math64x61.div(color.b, VAL_255);

    let (latent: Latent) = float_rgb_to_latent(Color(lin_r, lin_g, lin_b));

    return (latent,);
}

// @notice Convert float rgb to latent
// @param lin_color - Color, 64x61 fixed point
// @return latent - Latent, 64x61 fixed point
func float_rgb_to_latent{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(lin_color: Color) -> (latent: Latent) {
    alloc_locals;
    let (local r) = _clamp01(lin_color.r);
    let (local g) = _clamp01(lin_color.g);
    let (local b) = _clamp01(lin_color.b);

    let x = Math64x61.mul(r, 145268109580462718976);
    let y = Math64x61.mul(g, 145268109580462718976);
    let z = Math64x61.mul(b, 145268109580462718976);

    let ix = Math64x61.floor(x);
    let iy = Math64x61.floor(y);
    let iz = Math64x61.floor(z);

    let tx = x - ix;
    let ty = y - iy;
    let tz = z - iz;

    let val1 = Math64x61.add(ix, Math64x61.mul(iy, 147573952589676412928));
    let val2 = Math64x61.add(val1, Math64x61.mul(iz, 9444732965739290427392));
    let (xyz) = bitwise_and(Math64x61.toFelt(val2), 262143);

    let (c0: felt, c1: felt, c2: felt) = compute_latent(xyz, tx, ty, tz, 0, 0, 0);

    let lin_c0 = Math64x61.div(c0, VAL_255);
    let lin_c1 = Math64x61.div(c1, VAL_255);
    let lin_c2 = Math64x61.div(c2, VAL_255);
    let lin_c3 = Math64x61.sub(ONE, Math64x61.add3(lin_c0, lin_c1, lin_c2));

    let (_rgb: Color) = eval_polynomial(lin_c0, lin_c1, lin_c2, lin_c3);

    let r_mix = Math64x61.sub(r, _rgb.r);
    let g_mix = Math64x61.sub(g, _rgb.g);
    let b_mix = Math64x61.sub(b, _rgb.b);

    return (Latent(c0=lin_c0, c1=lin_c1, c2=lin_c2, c3=lin_c3, r=r_mix, g=g_mix, b=b_mix),);
}

// @notice compute latent with data from correspondance tables
func compute_latent{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(xyz: felt, tx: felt, ty: felt, tz: felt, c0: felt, c1: felt, c2: felt) -> (
    c0: felt, c1: felt, c2: felt
) {
    alloc_locals;

    let _w1 = Math64x61.mul(Math64x61.sub(ONE, tx), Math64x61.sub(ONE, ty));
    local w1 = Math64x61.mul(_w1, Math64x61.sub(ONE, tz));
    let (_c0_1) = get_c(c0, w1, xyz + 192);
    let (_c1_1) = get_c(c1, w1, xyz + 262336);
    let (_c2_1) = get_c(c2, w1, xyz + 524480);

    local _w2 = Math64x61.mul(tx, Math64x61.sub(ONE, ty));
    local w2 = Math64x61.mul(_w2, Math64x61.sub(ONE, tz));
    let (_c0_2) = get_c(_c0_1, w2, xyz + 193);
    let (_c1_2) = get_c(_c1_1, w2, xyz + 262337);
    let (_c2_2) = get_c(_c2_1, w2, xyz + 524481);

    local _w3 = Math64x61.mul(Math64x61.sub(ONE, tx), ty);
    local w3 = Math64x61.mul(_w3, Math64x61.sub(ONE, tz));
    let (_c0_3) = get_c(_c0_2, w3, xyz + 256);
    let (_c1_3) = get_c(_c1_2, w3, xyz + 262400);
    let (_c2_3) = get_c(_c2_2, w3, xyz + 524544);

    local _w4 = Math64x61.mul(tx, ty);
    local w4 = Math64x61.mul(_w4, Math64x61.sub(ONE, tz));
    let (_c0_4) = get_c(_c0_3, w4, xyz + 257);
    let (_c1_4) = get_c(_c1_3, w4, xyz + 262401);
    let (_c2_4) = get_c(_c2_3, w4, xyz + 524545);

    local _w5 = Math64x61.mul(Math64x61.sub(ONE, tx), Math64x61.sub(ONE, ty));
    local w5 = Math64x61.mul(_w5, tz);
    let (_c0_5) = get_c(_c0_4, w5, xyz + 4288);
    let (_c1_5) = get_c(_c1_4, w5, xyz + 266432);
    let (_c2_5) = get_c(_c2_4, w5, xyz + 528576);

    local _w6 = Math64x61.mul(tx, Math64x61.sub(ONE, ty));
    local w6 = Math64x61.mul(_w6, tz);
    let (_c0_6) = get_c(_c0_5, w6, xyz + 4289);
    let (_c1_6) = get_c(_c1_5, w6, xyz + 266433);
    let (_c2_6) = get_c(_c2_5, w6, xyz + 528577);

    local _w7 = Math64x61.mul(Math64x61.sub(ONE, tx), ty);
    local w7 = Math64x61.mul(_w7, tz);
    let (_c0_7) = get_c(_c0_6, w7, xyz + 4352);
    let (_c1_7) = get_c(_c1_6, w7, xyz + 266496);
    let (_c2_7) = get_c(_c2_6, w7, xyz + 528640);

    local _w8 = Math64x61.mul(tx, ty);
    local w8 = Math64x61.mul(_w8, tz);
    let (_c0_8) = get_c(_c0_7, w8, xyz + 4353);
    let (_c1_8) = get_c(_c1_7, w8, xyz + 266497);
    let (_c2_8) = get_c(_c2_7, w8, xyz + 528641);

    return (_c0_8, _c1_8, _c2_8);
}

// @notice get value from correspondance table
func get_c{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(c: felt, w: felt, c_data_pos: felt) -> (res: felt) {
    let (dw_index, pos) = unsigned_div_rem(c_data_pos, MAX_DATA_PER_FELT);
    let (data_index, remainder) = unsigned_div_rem(dw_index, DATA_LENGTH);
    let (contract_addr) = data_addr.read(data_index);
    let (data) = IData.get_data(contract_addr, remainder);
    let (elem) = view_get_element_at(data, pos);
    let elem_64x61 = Math64x61.fromFelt(elem);
    let _c = Math64x61.mul(w, elem_64x61);
    let res = Math64x61.add(c, _c);

    return (res,);
}

// @notice compute lerp latent
// @param latent1: first latent
// @param latent2: second latent
// @param t: proportion
// @return res: result latent
func lerp_latent{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(latent1: Latent, latent2: Latent, t: felt) -> (res: Latent) {
    let c0 = Math64x61.add(
        Math64x61.mul(Math64x61.sub(ONE, t), latent1.c0), Math64x61.mul(t, latent2.c0)
    );
    let c1 = Math64x61.add(
        Math64x61.mul(Math64x61.sub(ONE, t), latent1.c1), Math64x61.mul(t, latent2.c1)
    );
    let c2 = Math64x61.add(
        Math64x61.mul(Math64x61.sub(ONE, t), latent1.c2), Math64x61.mul(t, latent2.c2)
    );
    let c3 = Math64x61.add(
        Math64x61.mul(Math64x61.sub(ONE, t), latent1.c3), Math64x61.mul(t, latent2.c3)
    );
    let r = Math64x61.add(
        Math64x61.mul(Math64x61.sub(ONE, t), latent1.r), Math64x61.mul(t, latent2.r)
    );
    let g = Math64x61.add(
        Math64x61.mul(Math64x61.sub(ONE, t), latent1.g), Math64x61.mul(t, latent2.g)
    );
    let b = Math64x61.add(
        Math64x61.mul(Math64x61.sub(ONE, t), latent1.b), Math64x61.mul(t, latent2.b)
    );

    return (Latent(c0, c1, c2, c3, r, g, b),);
}

// @notice Convert latent to rgb
// @param latent: latent, 64x61
// @return color: rgb color, 64x61
@external
func latent_to_rgb{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(latent: Latent) -> (color: Color) {
    alloc_locals;
    let (rgb_mix: Color) = eval_polynomial(latent.c0, latent.c1, latent.c2, latent.c3);

    let (clamp_r) = _clamp01(Math64x61.add(rgb_mix.r, latent.r));
    let (clamp_g) = _clamp01(Math64x61.add(rgb_mix.g, latent.g));
    let (clamp_b) = _clamp01(Math64x61.add(rgb_mix.b, latent.b));

    let r = Math64x61.floor(Math64x61.round(Math64x61.mul(clamp_r, VAL_255)));
    let g = Math64x61.floor(Math64x61.round(Math64x61.mul(clamp_g, VAL_255)));
    let b = Math64x61.floor(Math64x61.round(Math64x61.mul(clamp_b, VAL_255)));

    return (Color(r, g, b),);
}

// @notice Eval polynomial based from data in correspondance tables
func eval_polynomial{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(c0: felt, c1: felt, c2: felt, c3: felt) -> (color: Color) {
    let c00 = Math64x61.mul(c0, c0);
    let c11 = Math64x61.mul(c1, c1);
    let c22 = Math64x61.mul(c2, c2);
    let c33 = Math64x61.mul(c3, c3);
    let c01 = Math64x61.mul(c0, c1);
    let c02 = Math64x61.mul(c0, c2);
    let c12 = Math64x61.mul(c1, c2);

    let w1 = Math64x61.mul(c0, c00);
    let r1 = Math64x61.mul(w1, 177943127117815646);
    let g1 = Math64x61.mul(w1, 65185674585009101);
    let b1 = Math64x61.mul(w1, 572609810010595882);

    let w2 = Math64x61.mul(c1, c11);
    let r2 = Math64x61.add(r1, Math64x61.mul(w2, 2211587110642925969));
    let g2 = Math64x61.add(g1, Math64x61.mul(w2, 1850589540325630866));
    let b2 = Math64x61.add(b1, Math64x61.mul(w2, 82130415580946945));

    let w3 = Math64x61.mul(c2, c22);
    let r3 = Math64x61.add(r2, Math64x61.mul(w3, 1722090581795954368));
    let g3 = Math64x61.add(g2, Math64x61.mul(w3, 112261949928556614));

    let w4 = Math64x61.mul(c3, c33);
    let r4 = Math64x61.add(r3, Math64x61.mul(w4, 2294732027972636662));
    let g4 = Math64x61.add(g3, Math64x61.mul(w4, 2305339159457750668));
    let b4 = Math64x61.add(b2, Math64x61.mul(w4, 2299036206767355312));

    let w5 = Math64x61.mul(c00, c1);
    let r5 = Math64x61.add(r4, Math64x61.mul(w5, 111121941144801364));
    let g5 = Math64x61.add(g4, Math64x61.mul(w5, 1922237916404713648));
    let b5 = Math64x61.add(b4, Math64x61.mul(w5, 749753547473977324));

    let w6 = Math64x61.mul(c01, c1);
    let r6 = Math64x61.add(r5, Math64x61.mul(w6, -1571361682567351411));
    let g6 = Math64x61.add(g5, Math64x61.mul(w6, 3369016561391215808));
    let b6 = Math64x61.add(b5, Math64x61.mul(w6, 2466812433947376030));

    let w7 = Math64x61.mul(c00, c2);
    let r7 = Math64x61.add(r6, Math64x61.mul(w7, 623924662915249915));
    let g7 = Math64x61.add(g6, Math64x61.mul(w7, -353367443566086620));
    let b7 = Math64x61.add(b6, Math64x61.mul(w7, 4582518418691349927));

    let w8 = Math64x61.mul(c02, c2);
    let r8 = Math64x61.add(r7, Math64x61.mul(w8, 1855700694998284033));
    let g8 = Math64x61.add(g7, Math64x61.mul(w8, 1547075621657109100));
    let b8 = Math64x61.add(b7, Math64x61.mul(w8, 424840045232577042));

    let w9 = Math64x61.mul(c00, c3);
    let r9 = Math64x61.add(r8, Math64x61.mul(w9, -807759933732939405));
    let g9 = Math64x61.add(g8, Math64x61.mul(w9, 3178738926614793903));
    let b9 = Math64x61.add(b8, Math64x61.mul(w9, 8505447815936092196));

    let w10 = Math64x61.mul(c0, c33);
    let r10 = Math64x61.add(r9, Math64x61.mul(w10, 2424087699413956416));
    let g10 = Math64x61.add(g9, Math64x61.mul(w10, 4561308859640860712));
    let b10 = Math64x61.add(b9, Math64x61.mul(w10, 6525283756609137104));

    let w11 = Math64x61.mul(c11, c2);
    let r11 = Math64x61.add(r10, Math64x61.mul(w11, 7415755408945646225));
    let g11 = Math64x61.add(g10, Math64x61.mul(w11, 1873963870910030082));
    let b11 = Math64x61.add(b10, Math64x61.mul(w11, 2383885165139305017));

    let w12 = Math64x61.mul(c1, c22);
    let r12 = Math64x61.add(r11, Math64x61.mul(w12, 6430843367539201933));
    let g12 = Math64x61.add(g11, Math64x61.mul(w12, 958436305857792474));
    let b12 = Math64x61.add(b11, Math64x61.mul(w12, -103469978060295628));

    let w13 = Math64x61.mul(c11, c3);
    let r13 = Math64x61.add(r12, Math64x61.mul(w13, 6967394658214445082));
    let g13 = Math64x61.add(g12, Math64x61.mul(w13, 5888525901367678283));
    let b13 = Math64x61.add(b12, Math64x61.mul(w13, 755535149059989464));

    let w14 = Math64x61.mul(c1, c33);
    let r14 = Math64x61.add(r13, Math64x61.mul(w14, 6805112055887015806));
    let g14 = Math64x61.add(g13, Math64x61.mul(w14, 6484056182883169849));
    let b14 = Math64x61.add(b13, Math64x61.mul(w14, 2711174285199377799));

    let w15 = Math64x61.mul(c22, c3);
    let r15 = Math64x61.add(r14, Math64x61.mul(w15, 6518088834667487615));
    let g15 = Math64x61.add(g14, Math64x61.mul(w15, 1843130368775125488));
    let b15 = Math64x61.add(b14, Math64x61.mul(w15, 4190068665501348105));

    let w16 = Math64x61.mul(c2, c33);
    let r16 = Math64x61.add(r15, Math64x61.mul(w16, 6910406255527190663));
    let g16 = Math64x61.add(g15, Math64x61.mul(w16, 2826803342382138710));
    let b16 = Math64x61.add(b15, Math64x61.mul(w16, 4165589813057105438));

    let w17 = Math64x61.mul(c01, c2);
    let r17 = Math64x61.add(r16, Math64x61.mul(w17, 4321013892879499411));
    let g17 = Math64x61.add(g16, Math64x61.mul(w17, 4727604943134837068));
    let b17 = Math64x61.add(b16, Math64x61.mul(w17, -687971227995277359));

    let w18 = Math64x61.mul(c01, c3);
    let r18 = Math64x61.add(r17, Math64x61.mul(w18, 5917013738584600063));
    let g18 = Math64x61.add(g17, Math64x61.mul(w18, 16219949928420861336));
    let b18 = Math64x61.add(b17, Math64x61.mul(w18, 1442889886868323450));

    let w19 = Math64x61.mul(c02, c3);
    let r19 = Math64x61.add(r18, Math64x61.mul(w19, 9415436861372348972));
    let g19 = Math64x61.add(g18, Math64x61.mul(w19, -3237596307294736389));
    let b19 = Math64x61.add(b18, Math64x61.mul(w19, 4957459214159489408));

    let w20 = Math64x61.mul(c12, c3);
    let r20 = Math64x61.add(r19, Math64x61.mul(w20, 13836872246444952862));
    let g20 = Math64x61.add(g19, Math64x61.mul(w20, 5892628895359843038));
    let b20 = Math64x61.add(b19, Math64x61.mul(w20, 4398153472676013960));

    return (Color(r20, g20, b20),);
}

func compute_w_proportions{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(target_val: felt, t_len: felt, t: felt*, z_len: felt, z: felt*, index: felt, res: felt) -> (
    res: felt
) {
    if (index == t_len) {
        return (res,);
    }
    let idx = (index * 7) + target_val;
    let val = Math64x61.mul(z[idx], t[index]);
    let _res = Math64x61.add(res, val);
    return compute_w_proportions(target_val, t_len, t, z_len, z, index + 1, _res);
}

// @notice For each color in the array, convert to latent and store in z
func rgb_to_latent_iter{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(color_len: felt, color: Color*, z_len: felt, z: felt*) {
    if (color_len == 0) {
        return ();
    }
    let (latent: Latent) = rgb_to_latent(color[0]);
    assert z[0] = latent.c0;
    assert z[1] = latent.c1;
    assert z[2] = latent.c2;
    assert z[3] = latent.c3;
    assert z[4] = latent.r;
    assert z[5] = latent.g;
    assert z[6] = latent.b;
    return rgb_to_latent_iter(color_len - 1, color + Color.SIZE, z_len + 7, z + 7);
}

// @notice Clamp value to [0, 1]
func _clamp01{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(val: felt) -> (
    res: felt
) {
    let res = Math64x61.min(Math64x61.max(val, 0), ONE);
    return (res,);
}

//
// Administration
//

// @external
// func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     new_implementation: felt
// ) {
//     Proxy.assert_only_admin();
//     Proxy._set_implementation_hash(new_implementation);
//     return ();
// }

// @external
// func upgrade_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     index: felt, contract_addr: felt
// ) {
//     Proxy.assert_only_admin();
//     assert_not_zero(contract_addr);
//     data_addr.write(index, contract_addr);
//     return ();
// }
