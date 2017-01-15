defmodule Sensors.Sht31 do
  use Bitwise

  @sht31_default_addr         0x44
  @sht31_meas_highrep_stretch <<0x2C, 0x06>>
  @sht31_meas_medrep_stretch  <<0x2C, 0x0D>>
  @sht31_meas_lowrep_stretch  <<0x2C, 0x10>>
  @sht31_meas_highrep         <<0x24, 0x00>>
  @sht31_meas_medrep          <<0x24, 0x0B>>
  @sht31_meas_lowrep          <<0x24, 0x16>>
  @sht31_readstatus           <<0xF3, 0x2D>>
  @sht31_clearstatus          <<0x30, 0x41>>
  @sht31_softreset            <<0x30, 0xA2>>
  @sht31_heateren             <<0x30, 0x6D>>
  @sht31_heaterdis            <<0x30, 0x66>>

  # Inspired by: https://github.com/adafruit/Adafruit_SHT31/blob/master/Adafruit_SHT31.cpp
  # SHT31 Reference: https://www.sensirion.com/fileadmin/user_upload/customers/sensirion/Dokumente/Humidity_Sensors/Sensirion_Humidity_Sensors_SHT3x_Datasheet_digital.pdf

  def init do
    {:ok, pid} = I2c.start_link("i2c-1", @sht31_default_addr)

    pid
  end

  def reset(pid) do
    I2c.write(pid, @sht31_softreset);
    Process.sleep(10);
  end

  def test do
    IO.puts("test")
  end

  def readStatus(pid) do
    I2c.write(pid, @sht31_readstatus);

    << stat :: size(16), stat_crc >> = I2c.read(pid, 3);
    stat
  end

  def heater(pid, enabled) do
    if (enabled) do
      I2c.write(pid, @sht31_heateren);
    else
      I2c.write(pid, @sht31_heaterdis);
    end
  end

  def readTempHum(pid) do

    I2c.write(pid, @sht31_meas_highrep);

    Process.sleep(500);

    # Pattern match value into sensor readings, following SHT31 Documentation
    << st :: size(16), st_crc, srh :: size(16), srh_crc >> = reading = I2c.read(pid, 6);
    << st0, st1, _crc1, srh0, srh1, _crc2 >> = reading

    temp = { ( st * 175 ) / 0xffff - 45.00, :celsius }
    hum  = { ( st * 100 ) / 0xffff, :rel_hum }

    IO.puts("Raw values: st => #{st}, st_crc => #{st_crc} == #{crc([st0,st1 ])}")
    IO.puts("Raw values: srh => #{srh}, srh_crc => #{srh_crc} / #{crc([srh0, srh1])}")

    if crc([st0,st1]) == st_crc and crc([srh0,srh1]) == srh_crc do
      {:ok, %{ temp: temp, humidity: hum }}
    else
      {:error, %{ temp_crc: crc([st0,st1]) == st_crc, humidity_crc: crc([srh0,srh1]) == srh_crc }}
    end
  end

  # CRC-8 formula (page 14 of SHT spec pdf)
  #
  # Initialization data 0xFF
  # Polynomial 0x31 (x8 + x5 +x4 +1)
  # Final XOR 0x00
  def crc(dataList) do
    polynomial = 0x31
    crc = 0xFF

    # Equivalent to outer loop of C++ CRC function
    # dataList = data |> Enum.map(fn << x >> -> x end)
    checksum = fn _i, crc! ->
      if (crc! &&& 0x80) > 0x0 do
        (crc! <<< 1) ^^^ polynomial
      else
        (crc! <<< 1)
      end
    end

    crc! = Enum.reduce dataList, crc, fn data, crc! ->
      Enum.reduce(1..8, crc! ^^^ data, checksum)
    end

    crc! &&& 0xFF # reduce to single byte
  end

end
