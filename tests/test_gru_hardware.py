import unittest
from model.gru_hardware import HardwareGRU,image,sigmoid,tanh,SIG,TAN
from model.quantize import rounded
class HardwareContract(unittest.TestCase):
 def test_activation_bound_symmetry_monotonic(self):
  ps,pt=-1,-4097
  for x in range(-32768,32768):
   s,t=sigmoid(x),tanh(x)
   self.assertTrue(0<=s<=4096 and -4096<=t<=4096)
   self.assertGreaterEqual(s,ps);self.assertGreaterEqual(t,pt);ps,pt=s,t
   self.assertEqual(s+sigmoid(-x),4096);self.assertEqual(t,-tanh(-x))
 def test_image_validation(self):
  p=image(8,16);self.assertTrue(all(-128<=v<=127 for v in p[:1168]))
  for bad in [[],[128]+p[1:],p[:-1]+[1<<31]]:
   with self.assertRaises(ValueError):HardwareGRU(parameters=bad)
 def test_zero_loaded_head_and_flush(self):
  h=HardwareGRU(parameters=[0]*1217)
  for _ in range(3):
   a=h.step([32767]*8);self.assertEqual(a['score'],32768);self.assertEqual(a['h'],[0]*16)
  h.flush();self.assertIsNone(h.average);self.assertFalse(h.alert)
 def test_update_reset_bias_contract(self):
  # Scalar-loop oracle stores no mixed-frame state; explicit head bias controls score.
  h=HardwareGRU();a=h.step([4096]*8);old=a['h'];b=h.step([-4096]*8)
  self.assertEqual(b['q'],[rounded(r*x) for r,x in zip(b['r'],old)])
  self.assertEqual(b['h'],[rounded(z*x+(4096-z)*n) for z,x,n in zip(b['z'],old,b['n'])])
 def test_maximum_accumulator_bound(self):
  self.assertLess((1<<31)+48*32768*128,1<<39)
  a=HardwareGRU(16,32,image(16,32,True)).step([-32768]*16)
  self.assertEqual(a['sat'],1)
if __name__=='__main__':unittest.main()
