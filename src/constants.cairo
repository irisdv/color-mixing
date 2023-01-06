const LATENT_SIZE = 7;
const MAX_DATA_PER_FELT = 31;
const ONE = 2305843009213693952;
const VAL_255 = 587989967349491957760;
const DATA_LENGTH = 5100;

struct Color {
    r: felt,
    g: felt,
    b: felt,
}

struct Latent {
    c0: felt,
    c1: felt,
    c2: felt,
    c3: felt,
    r: felt,
    g: felt,
    b: felt,
}
