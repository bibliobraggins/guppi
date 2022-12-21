use rustler::{Env, Binary, OwnedBinary, NifResult};

static ULAW_LOOKUP_TABLE: [i16;256] = [
        -32124,-31100,-30076,-29052,-28028,-27004,-25980,-24956,
        -23932,-22908,-21884,-20860,-19836,-18812,-17788,-16764,
        -15996,-15484,-14972,-14460,-13948,-13436,-12924,-12412,
        -11900,-11388,-10876,-10364, -9852, -9340, -8828, -8316,
        -7932, -7676, -7420, -7164, -6908, -6652, -6396, -6140,
        -5884, -5628, -5372, -5116, -4860, -4604, -4348, -4092,
        -3900, -3772, -3644, -3516, -3388, -3260, -3132, -3004,
        -2876, -2748, -2620, -2492, -2364, -2236, -2108, -1980,
        -1884, -1820, -1756, -1692, -1628, -1564, -1500, -1436,
        -1372, -1308, -1244, -1180, -1116, -1052,  -988,  -924,
        -876,  -844,  -812,  -780,  -748,  -716,  -684,  -652,
        -620,  -588,  -556,  -524,  -492,  -460,  -428,  -396,
        -372,  -356,  -340,  -324,  -308,  -292,  -276,  -260,
        -244,  -228,  -212,  -196,  -180,  -164,  -148,  -132,
        -120,  -112,  -104,   -96,   -88,   -80,   -72,   -64,
        -56,   -48,   -40,   -32,   -24,   -16,    -8,    -1,
        32124, 31100, 30076, 29052, 28028, 27004, 25980, 24956,
        23932, 22908, 21884, 20860, 19836, 18812, 17788, 16764,
        15996, 15484, 14972, 14460, 13948, 13436, 12924, 12412,
        11900, 11388, 10876, 10364,  9852,  9340,  8828,  8316,
        7932,  7676,  7420,  7164,  6908,  6652,  6396,  6140,
        5884,  5628,  5372,  5116,  4860,  4604,  4348,  4092,
        3900,  3772,  3644,  3516,  3388,  3260,  3132,  3004,
        2876,  2748,  2620,  2492,  2364,  2236,  2108,  1980,
        1884,  1820,  1756,  1692,  1628,  1564,  1500,  1436,
        1372,  1308,  1244,  1180,  1116,  1052,   988,   924,
        876,   844,   812,   780,   748,   716,   684,   652,
        620,   588,   556,   524,   492,   460,   428,   396,
        372,   356,   340,   324,   308,   292,   276,   260,
        244,   228,   212,   196,   180,   164,   148,   132,
        120,   112,   104,    96,    88,    80,    72,    64,
        56,    48,    40,    32,    24,    16,     8,     0
    ];

#[rustler::nif]
fn linear_to_ulaw(sample: i16) -> u8 {
  compress_ulaw(sample)
}

fn compress_ulaw(sample: i16) -> u8 {
  let mut pcm_value = sample;
  let sign = (pcm_value >> 8) & 0x80;
  if sign != 0 {
    pcm_value = -pcm_value;
  }
  if pcm_value > 0x7F7B {
    pcm_value = 0x7F7B;
  }
  pcm_value += 0x84;
  let mut exponent: i16 = 7;
  let mut mask = 0x4000;
  while pcm_value & mask == 0 {
    exponent -= 1;
    mask >>= 1;
  }
  let mantissa: i16 = (pcm_value >> (exponent + 3)) & 0x0f;
  let ulaw_value = sign | exponent << 4 | mantissa;
  (!ulaw_value) as u8
}

#[rustler::nif]
pub fn ulaw_to_linear(sample: u8) -> i16 {
  expand_ulaw(sample)
}

fn expand_ulaw(sample: u8) -> i16 {
  ULAW_LOOKUP_TABLE[sample as usize]
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
    [bytes[0], bytes[1]] = i16_to_bytes(vec[i]);
    i+=1;
  };

  Ok(Binary::from_owned(out_buff, env))
}

#[rustler::nif]
pub fn compress_ulaw_buffer<'a>(env: Env<'a>, buff: Binary<'a>) -> NifResult<Binary<'a>> {
  let mut out_buff = OwnedBinary::new(buff.len()/2).unwrap();

  let mut vec = Vec::new();
  for sample in buff.as_slice().chunks(2) {
    vec.push(
      compress_ulaw(((( sample[0] as u16 ) << 8) | sample[1] as u16 ) as i16)
    );
  }

  let mut i = 0;
  for byte in out_buff.as_mut_slice() {
    *byte = vec[i];
    i+=1;
  }

  Ok(Binary::from_owned(out_buff, env))
}

fn i16_to_bytes(sample: i16) -> [u8;2] {
  [
    ((sample >> 0) & 0xff) as u8,
    ((sample >> 8) & 0xff) as u8
  ]
}
