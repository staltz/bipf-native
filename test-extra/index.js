const tape = require('tape')
const bipf = require('../')

tape('encode string', (t) => {
  const input = {a: 'hello', x: Buffer.from('abc'), z: 123.456}
  console.log('IN:  ', input)

  var len = bipf.encodingLength(input)
  var buffer = Buffer.alloc(len)
  bipf.encode(input, buffer, 0)
  console.log('MID: ', buffer)

  const output = bipf.decode(buffer, 0)
  console.log('OUT: ', output);

  t.end()
})
