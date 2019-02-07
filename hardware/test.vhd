
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.Utils.all;
use work.Encoding.all;

entity test is
  port(
    zigzag               : in  std_logic_vector(31 downto 0);
    decoded              : out std_logic_vector(31 downto 0);
    encoded              : out std_logic_vector(31 downto 0)
  );
end test;

architecture behv of test is
begin
  decoded <= std_logic_vector(to_signed(decode_zigzag(zigzag), 32));
  encoded <= std_logic_vector(to_signed(encode_zigzag(zigzag), 32));
end behv;