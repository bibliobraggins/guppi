use rustler::{Env, Binary, OwnedBinary, NifResult};

static ULAW_TO_LINEAR: [i16;256] = [
  -32124,-31100,-30076,-29052,-28028,-27004,-25980,-24956,
  -23932,-22908,-21884,-20860,-19836,-18812,-17788,-16764,
  -15996,-15484,-14972,-14460,-13948,-13436,-12924,-12412,
  -11900,-11388,-10876,-10364,-9852, -9340, -8828, -8316,
  -7932, -7676, -7420, -7164, -6908, -6652, -6396, -6140,
  -5884, -5628, -5372, -5116, -4860, -4604, -4348, -4092,
  -3900, -3772, -3644, -3516, -3388, -3260, -3132, -3004,
  -2876, -2748, -2620, -2492, -2364, -2236, -2108, -1980,
  -1884, -1820, -1756, -1692, -1628, -1564, -1500, -1436,
  -1372, -1308, -1244, -1180, -1116, -1052, -988,  -924,
  -876,  -844,  -812,  -780,  -748,  -716,  -684,  -652,
  -620,  -588,  -556,  -524,  -492,  -460,  -428,  -396,
  -372,  -356,  -340,  -324,  -308,  -292,  -276,  -260,
  -244,  -228,  -212,  -196,  -180,  -164,  -148,  -132,
  -120,  -112,  -104,  -96,   -88,   -80,   -72,   -64,
  -56,   -48,   -40,   -32,   -24,   -16,   -8,    -1,
  32124, 31100, 30076, 29052, 28028, 27004, 25980, 24956,
  23932, 22908, 21884, 20860, 19836, 18812, 17788, 16764,
  15996, 15484, 14972, 14460, 13948, 13436, 12924, 12412,
  11900, 11388, 10876, 10364, 9852,  9340,  8828,  8316,
  7932,  7676,  7420,  7164,  6908,  6652,  6396,  6140,
  5884,  5628,  5372,  5116,  4860,  4604,  4348,  4092,
  3900,  3772,  3644,  3516,  3388,  3260,  3132,  3004,
  2876,  2748,  2620,  2492,  2364,  2236,  2108,  1980,
  1884,  1820,  1756,  1692,  1628,  1564,  1500,  1436,
  1372,  1308,  1244,  1180,  1116,  1052,  988,   924,
  876,   844,   812,   780,   748,   716,   684,   652,
  620,   588,   556,   524,   492,   460,   428,   396,
  372,   356,   340,   324,   308,   292,   276,   260,
  244,   228,   212,   196,   180,   164,   148,   132,
  120,   112,   104,   96,    88,    80,    72,    64,
  56,    48,    40,    32,    24,    16,    8,     0
];

static ALAW_TO_LINEAR: [i16; 256] = [
   -5504, -5248, -6016, -5760, -4480, -4224, -4992, -4736,
   -7552, -7296, -8064, -7808, -6528, -6272, -7040, -6784,
   -2752, -2624, -3008, -2880, -2240, -2112, -2496, -2368,
   -3776, -3648, -4032, -3904, -3264, -3136, -3520, -3392,
   -22016,-20992,-24064,-23040,-17920,-16896,-19968,-18944,
   -30208,-29184,-32256,-31232,-26112,-25088,-28160,-27136,
   -11008,-10496,-12032,-11520,-8960, -8448, -9984, -9472,
   -15104,-14592,-16128,-15616,-13056,-12544,-14080,-13568,
   -344,  -328,  -376,  -360,  -280,  -264,  -312,  -296,
   -472,  -456,  -504,  -488,  -408,  -392,  -440,  -424,
   -88,   -72,   -120,  -104,  -24,   -8,    -56,   -40,
   -216,  -200,  -248,  -232,  -152,  -136,  -184,  -168,
   -1376, -1312, -1504, -1440, -1120, -1056, -1248, -1184,
   -1888, -1824, -2016, -1952, -1632, -1568, -1760, -1696,
   -688,  -656,  -752,  -720,  -560,  -528,  -624,  -592,
   -944,  -912,  -1008, -976,  -816,  -784,  -880,  -848,
    5504,  5248,  6016,  5760,  4480,  4224,  4992,  4736,
    7552,  7296,  8064,  7808,  6528,  6272,  7040,  6784,
    2752,  2624,  3008,  2880,  2240,  2112,  2496,  2368,
    3776,  3648,  4032,  3904,  3264,  3136,  3520,  3392,
    22016, 20992, 24064, 23040, 17920, 16896, 19968, 18944,
    30208, 29184, 32256, 31232, 26112, 25088, 28160, 27136,
    11008, 10496, 12032, 11520, 8960,  8448,  9984,  9472,
    15104, 14592, 16128, 15616, 13056, 12544, 14080, 13568,
    344,   328,   376,   360,   280,   264,   312,   296,
    472,   456,   504,   488,   408,   392,   440,   424,
    88,    72,   120,   104,    24,     8,    56,    40,
    216,   200,   248,   232,   152,   136,   184,   168,
    1376,  1312,  1504,  1440,  1120,  1056,  1248,  1184,
    1888,  1824,  2016,  1952,  1632,  1568,  1760,  1696,
    688,   656,   752,   720,   560,   528,   624,   592,
    944,   912,  1008,   976,   816,   784,   880,   848 
];

static ULAW_TO_ALAW: [u8;128] = [
  1,    1,    2,    2,    3,    3,    4,    4,
  5,    5,    6,    6,    7,    7,    8,    8,
  9,    10,   11,   12,   13,   14,   15,   16,
  17,   18,   19,   20,   21,   22,   23,   24,
  25,   27,   29,   31,   33,   34,   35,   36,
  37,   38,   39,   40,   41,   42,   43,   44,
  46,   48,   49,   50,   51,   52,   53,   54,
  55,   56,   57,   58,   59,   60,   61,   62,
  64,   65,   66,   67,   68,   69,   70,   71,
  72,   73,   74,   75,   76,   77,   78,   79,
  80,   82,   83,   84,   85,   86,   87,   88,
  89,   90,   91,   92,   93,   94,   95,   96,
  97,   98,   99,   100,  101,  102,  103,  104,
  105,  106,  107,  108,  109,  110,  111,  112,
  113,  114,  115,  116,  117,  118,  119,  120,
  121,  122,  123,  124,  125,  126,  127,  128
];

static ALAW_TO_ULAW: [u8; 128] = [
  1,    3,    5,    7,    9,    11,   13,   15,
  16,   17,   18,   19,   20,   21,   22,   23,
  24,   25,   26,   27,   28,   29,   30,   31,
  32,   32,   33,   33,   34,   34,   35,   35,
  36,   37,   38,   39,   40,   41,   42,   43,
  44,   45,   46,   47,   48,   48,   49,   49,
  50,   51,   52,   53,   54,   55,   56,   57,
  58,   59,   60,   61,   62,   63,   64,   64,
  65,   66,   67,   68,   69,   70,   71,   72,
  73,   74,   75,   76,   77,   78,   79,   80,
  80,   81,   82,   83,   84,   85,   86,   87,
  88,   89,   90,   91,   92,   93,   94,   95,
  96,   97,   98,   99,   100,  101,  102,  103,
  104,  105,  106,  107,  108,  109,  110,  111,
  112,  113,  114,  115,  116,  117,  118,  119,
  120,  121,  122,  123,  124,  125,  126,  127
];

fn expand_ulaw(sample: u8) -> i16 {
  ULAW_TO_LINEAR[sample as usize]
}

fn expand_alaw(sample: u8) -> i16 {
  ALAW_TO_LINEAR[(sample) as usize]
}

fn u_to_a(sample: u8) -> u8 {
  ULAW_TO_ALAW[sample as usize]
}

fn a_to_u(sample: u8) -> u8 {
  ALAW_TO_ULAW[sample as usize]
}

// can we eliminate this function call? need to investigate later
fn i16_to_bytes(sample: i16) -> [u8;2] {
  [
    ((sample >> 0) & 0xff) as u8,
    ((sample >> 8) & 0xff) as u8
  ]
}

#[allow(overflowing_literals, unused_comparisons)]
pub fn compress_alaw(sample: i16) -> u8 {
  let mut pcm_value = sample;
  let sign = (pcm_value & 0x8000) >> 8;
  if sign != 0 {
    pcm_value = -pcm_value;
  }
  // Clip at 15-bits
  if pcm_value > 0x7fff {
    pcm_value = 0x7fff;
  }
  let mut exponent: i16 = 7;
  let mut mask = 0x4000;
  while pcm_value & mask == 0 && exponent > 0 {
    exponent -= 1;
    mask >>= 1;
  }
  let manitssa: i16 =
    if exponent == 0 {
      (pcm_value >> 4) & 0x0f
    }
    else {
      (pcm_value >> (exponent + 3)) & 0x0f
    };
  let alaw_value = sign | exponent << 4 | manitssa;
  (alaw_value ^ 0xd5) as u8
}

fn compress_ulaw(mut sample: i16) -> u8 {
  let sign = (sample >> 8) & 0x80;
  if sign != 0 {
    sample = -sample;
  }
  if sample > 0x7f7b {
    sample = 0x7f7b;
  }
  sample += 0x84;
  let mut exponent: i16 = 7;
  let mut mask = 0x4000;
  while sample & mask == 0 {
    exponent -= 1;
    mask >>= 1;
  }
  let mantissa: i16 = (sample >> (exponent + 3)) & 0x0f;
  let ulaw_value = sign | exponent << 4 | mantissa;
  (!ulaw_value) as u8
}

#[rustler::nif]
fn linear_to_ulaw(sample: i16) -> u8 {
  compress_ulaw(sample)
}

#[rustler::nif]
fn linear_to_alaw(sample: i16) -> u8 {
  compress_alaw(sample)
}

#[rustler::nif]
fn ulaw_to_alaw(sample: u8) -> u8 {
  u_to_a(sample)
}

#[rustler::nif]
fn alaw_to_ulaw(sample: u8) -> u8 {
  a_to_u(sample)
}

#[rustler::nif]
fn ulaw_to_linear(sample: u8) -> i16 {
  expand_ulaw(sample)
}

#[rustler::nif]
fn alaw_to_linear(sample: u8) -> i16 {
  expand_alaw(sample)
}

#[rustler::nif]
pub fn expand_ulaw_buffer<'a>(env: Env<'a>, buff: Binary<'a>) -> NifResult<Binary<'a>> {
  let mut out_buff = OwnedBinary::new(buff.len()*2).unwrap();

  let mut vec = Vec::new();
  for sample in buff.as_slice() {
    vec.push(
      expand_ulaw(*sample)
    )
  };

  let mut i = 0;
  for bytes in out_buff.as_mut_slice().chunks_mut(2) {
    // position swap bytes
    [bytes[1], bytes[0]] = i16_to_bytes(vec[i]);
    i+=1;
  };

  Ok(Binary::from_owned(out_buff, env))
}

#[rustler::nif]
pub fn ulaw_to_alaw_buffer<'a>(env: Env<'a>, buff: Binary<'a>) -> NifResult<Binary<'a>> {
  let mut out_buff = OwnedBinary::from_unowned(&buff).unwrap();

  for sample in out_buff.as_mut_slice() {
    *sample = u_to_a(*sample)
  };

  Ok(Binary::from_owned(out_buff, env))
}

#[rustler::nif]
pub fn alaw_to_ulaw_buffer<'a>(env: Env<'a>, buff: Binary<'a>) -> NifResult<Binary<'a>> {
  let mut out_buff = OwnedBinary::from_unowned(&buff).unwrap();

  for sample in out_buff.as_mut_slice() {
    *sample = a_to_u(*sample)
  };

  Ok(Binary::from_owned(out_buff, env))
}

#[rustler::nif]
pub fn compress_ulaw_buffer<'a>(env: Env<'a>, buff: Binary<'a>) -> NifResult<Binary<'a>> {
  let mut out_buff = OwnedBinary::new(buff.len()/2).unwrap();

  let mut vec = Vec::new();
  for sample in buff.as_slice().chunks(2) {
    vec.push(
      compress_ulaw((((sample[0] as u16 ) << 8) | sample[1] as u16 ) as i16)
    );
  }

  let mut i = 0;
  for byte in out_buff.as_mut_slice() {
    *byte = vec[i];
    i+=1;
  }

  Ok(Binary::from_owned(out_buff, env))
}

#[rustler::nif]
pub fn expand_alaw_buffer<'a>(env: Env<'a>, buff: Binary<'a>) -> NifResult<Binary<'a>> {
  let mut out_buff = OwnedBinary::new(buff.len()*2).unwrap();

  let mut vec = Vec::new();
  for sample in buff.as_slice() {
    vec.push(
      expand_alaw(*sample)
    )
  };

  let mut i = 0;
  for bytes in out_buff.as_mut_slice().chunks_mut(2) {
    // position swap bytes
    [bytes[1], bytes[0]] = i16_to_bytes(vec[i]);
    i+=1;
  };

  Ok(Binary::from_owned(out_buff, env))
}

#[rustler::nif]
pub fn compress_alaw_buffer<'a>(env: Env<'a>, buff: Binary<'a>) -> NifResult<Binary<'a>> {
  let mut out_buff = OwnedBinary::new(buff.len()/2).unwrap();

  let mut vec = Vec::new();
  for sample in buff.as_slice().chunks(2) {
    vec.push(
      compress_alaw((((sample[0] as u16 ) << 8) | sample[1] as u16 ) as i16)
    );
  }

  let mut i = 0;
  for byte in out_buff.as_mut_slice() {
    *byte = vec[i];
    i+=1;
  }

  Ok(Binary::from_owned(out_buff, env))
}
