
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.Utils.all;

entity test_tb is
end test_tb;

architecture tb of test_tb is
	signal zigzag	 : std_logic_vector(31 downto 0);
	signal decoded  : std_logic_vector(31 downto 0);
  signal encoded : std_logic_vector(31 downto 0);
begin
  dut : entity work.test
  port map(zigzag   =>  zigzag,
           decoded  => decoded,
           encoded  => encoded);

  simulation : process
  begin
    zigzag <= slv(0, 32);
    wait for 5 ns;
    zigzag <= slv(15, 32);
    wait for 5 ns;
    zigzag <= slv(64, 32);
    wait for 5 ns;
    zigzag <= std_logic_vector(to_signed(-64, 32));
    wait for 5 ns;
    zigzag <= std_logic_vector(to_signed(-5, 32));
    wait;
  end process;
end tb;