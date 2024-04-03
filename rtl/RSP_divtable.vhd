library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   

library mem;
use work.pFunctions.all;
use work.pRSP.all;

entity RSP_divtable is
   port 
   (
      clk1x   : in  std_logic;
      address : in unsigned(9 downto 0);
      data    : out signed(15 downto 0) := (others => '0')
   );
end entity;

architecture arch of RSP_divtable is
         
   type t_lookup is array(0 to 1023) of signed(15 downto 0);  
   signal divtable : t_lookup := 
   (
      x"ffff",x"ff00",x"fe01",x"fd04",x"fc07",x"fb0c",x"fa11",x"f918",x"f81f",x"f727",x"f631",x"f53b",x"f446",x"f352",x"f25f",x"f16d",
      x"f07c",x"ef8b",x"ee9c",x"edae",x"ecc0",x"ebd3",x"eae8",x"e9fd",x"e913",x"e829",x"e741",x"e65a",x"e573",x"e48d",x"e3a9",x"e2c5",
      x"e1e1",x"e0ff",x"e01e",x"df3d",x"de5d",x"dd7e",x"dca0",x"dbc2",x"dae6",x"da0a",x"d92f",x"d854",x"d77b",x"d6a2",x"d5ca",x"d4f3",
      x"d41d",x"d347",x"d272",x"d19e",x"d0cb",x"cff8",x"cf26",x"ce55",x"cd85",x"ccb5",x"cbe6",x"cb18",x"ca4b",x"c97e",x"c8b2",x"c7e7",
      x"c71c",x"c652",x"c589",x"c4c0",x"c3f8",x"c331",x"c26b",x"c1a5",x"c0e0",x"c01c",x"bf58",x"be95",x"bdd2",x"bd10",x"bc4f",x"bb8f",
      x"bacf",x"ba10",x"b951",x"b894",x"b7d6",x"b71a",x"b65e",x"b5a2",x"b4e8",x"b42e",x"b374",x"b2bb",x"b203",x"b14b",x"b094",x"afde",
      x"af28",x"ae73",x"adbe",x"ad0a",x"ac57",x"aba4",x"aaf1",x"aa40",x"a98e",x"a8de",x"a82e",x"a77e",x"a6d0",x"a621",x"a574",x"a4c6",
      x"a41a",x"a36e",x"a2c2",x"a217",x"a16d",x"a0c3",x"a01a",x"9f71",x"9ec8",x"9e21",x"9d79",x"9cd3",x"9c2d",x"9b87",x"9ae2",x"9a3d",
      x"9999",x"98f6",x"9852",x"97b0",x"970e",x"966c",x"95cb",x"952b",x"948b",x"93eb",x"934c",x"92ad",x"920f",x"9172",x"90d4",x"9038",
      x"8f9c",x"8f00",x"8e65",x"8dca",x"8d30",x"8c96",x"8bfc",x"8b64",x"8acb",x"8a33",x"899c",x"8904",x"886e",x"87d8",x"8742",x"86ad",
      x"8618",x"8583",x"84f0",x"845c",x"83c9",x"8336",x"82a4",x"8212",x"8181",x"80f0",x"8060",x"7fd0",x"7f40",x"7eb1",x"7e22",x"7d93",
      x"7d05",x"7c78",x"7beb",x"7b5e",x"7ad2",x"7a46",x"79ba",x"792f",x"78a4",x"781a",x"7790",x"7706",x"767d",x"75f5",x"756c",x"74e4",
      x"745d",x"73d5",x"734f",x"72c8",x"7242",x"71bc",x"7137",x"70b2",x"702e",x"6fa9",x"6f26",x"6ea2",x"6e1f",x"6d9c",x"6d1a",x"6c98",
      x"6c16",x"6b95",x"6b14",x"6a94",x"6a13",x"6993",x"6914",x"6895",x"6816",x"6798",x"6719",x"669c",x"661e",x"65a1",x"6524",x"64a8",
      x"642c",x"63b0",x"6335",x"62ba",x"623f",x"61c5",x"614b",x"60d1",x"6058",x"5fdf",x"5f66",x"5eed",x"5e75",x"5dfd",x"5d86",x"5d0f",
      x"5c98",x"5c22",x"5bab",x"5b35",x"5ac0",x"5a4b",x"59d6",x"5961",x"58ed",x"5879",x"5805",x"5791",x"571e",x"56ac",x"5639",x"55c7",
      x"5555",x"54e3",x"5472",x"5401",x"5390",x"5320",x"52af",x"5240",x"51d0",x"5161",x"50f2",x"5083",x"5015",x"4fa6",x"4f38",x"4ecb",
      x"4e5e",x"4df1",x"4d84",x"4d17",x"4cab",x"4c3f",x"4bd3",x"4b68",x"4afd",x"4a92",x"4a27",x"49bd",x"4953",x"48e9",x"4880",x"4817",
      x"47ae",x"4745",x"46dc",x"4674",x"460c",x"45a5",x"453d",x"44d6",x"446f",x"4408",x"43a2",x"433c",x"42d6",x"4270",x"420b",x"41a6",
      x"4141",x"40dc",x"4078",x"4014",x"3fb0",x"3f4c",x"3ee8",x"3e85",x"3e22",x"3dc0",x"3d5d",x"3cfb",x"3c99",x"3c37",x"3bd6",x"3b74",
      x"3b13",x"3ab2",x"3a52",x"39f1",x"3991",x"3931",x"38d2",x"3872",x"3813",x"37b4",x"3755",x"36f7",x"3698",x"363a",x"35dc",x"357f",
      x"3521",x"34c4",x"3467",x"340a",x"33ae",x"3351",x"32f5",x"3299",x"323e",x"31e2",x"3187",x"312c",x"30d1",x"3076",x"301c",x"2fc2",
      x"2f68",x"2f0e",x"2eb4",x"2e5b",x"2e02",x"2da9",x"2d50",x"2cf8",x"2c9f",x"2c47",x"2bef",x"2b97",x"2b40",x"2ae8",x"2a91",x"2a3a",
      x"29e4",x"298d",x"2937",x"28e0",x"288b",x"2835",x"27df",x"278a",x"2735",x"26e0",x"268b",x"2636",x"25e2",x"258d",x"2539",x"24e5",
      x"2492",x"243e",x"23eb",x"2398",x"2345",x"22f2",x"22a0",x"224d",x"21fb",x"21a9",x"2157",x"2105",x"20b4",x"2063",x"2012",x"1fc1",
      x"1f70",x"1f1f",x"1ecf",x"1e7f",x"1e2e",x"1ddf",x"1d8f",x"1d3f",x"1cf0",x"1ca1",x"1c52",x"1c03",x"1bb4",x"1b66",x"1b17",x"1ac9",
      x"1a7b",x"1a2d",x"19e0",x"1992",x"1945",x"18f8",x"18ab",x"185e",x"1811",x"17c4",x"1778",x"172c",x"16e0",x"1694",x"1648",x"15fd",
      x"15b1",x"1566",x"151b",x"14d0",x"1485",x"143b",x"13f0",x"13a6",x"135c",x"1312",x"12c8",x"127f",x"1235",x"11ec",x"11a3",x"1159",
      x"1111",x"10c8",x"107f",x"1037",x"0fef",x"0fa6",x"0f5e",x"0f17",x"0ecf",x"0e87",x"0e40",x"0df9",x"0db2",x"0d6b",x"0d24",x"0cdd",
      x"0c97",x"0c50",x"0c0a",x"0bc4",x"0b7e",x"0b38",x"0af2",x"0aad",x"0a68",x"0a22",x"09dd",x"0998",x"0953",x"090f",x"08ca",x"0886",
      x"0842",x"07fd",x"07b9",x"0776",x"0732",x"06ee",x"06ab",x"0668",x"0624",x"05e1",x"059e",x"055c",x"0519",x"04d6",x"0494",x"0452",
      x"0410",x"03ce",x"038c",x"034a",x"0309",x"02c7",x"0286",x"0245",x"0204",x"01c3",x"0182",x"0141",x"0101",x"00c0",x"0080",x"0040",
      -- sqrt part
      x"ffff",x"ff00",x"fe02",x"fd06",x"fc0b",x"fb12",x"fa1a",x"f923",x"f82e",x"f73b",x"f648",x"f557",x"f467",x"f379",x"f28c",x"f1a0",
      x"f0b6",x"efcd",x"eee5",x"edff",x"ed19",x"ec35",x"eb52",x"ea71",x"e990",x"e8b1",x"e7d3",x"e6f6",x"e61b",x"e540",x"e467",x"e38e",
      x"e2b7",x"e1e1",x"e10d",x"e039",x"df66",x"de94",x"ddc4",x"dcf4",x"dc26",x"db59",x"da8c",x"d9c1",x"d8f7",x"d82d",x"d765",x"d69e",
      x"d5d7",x"d512",x"d44e",x"d38a",x"d2c8",x"d206",x"d146",x"d086",x"cfc7",x"cf0a",x"ce4d",x"cd91",x"ccd6",x"cc1b",x"cb62",x"caa9",
      x"c9f2",x"c93b",x"c885",x"c7d0",x"c71c",x"c669",x"c5b6",x"c504",x"c453",x"c3a3",x"c2f4",x"c245",x"c198",x"c0eb",x"c03f",x"bf93",
      x"bee9",x"be3f",x"bd96",x"bced",x"bc46",x"bb9f",x"baf8",x"ba53",x"b9ae",x"b90a",x"b867",x"b7c5",x"b723",x"b681",x"b5e1",x"b541",
      x"b4a2",x"b404",x"b366",x"b2c9",x"b22c",x"b191",x"b0f5",x"b05b",x"afc1",x"af28",x"ae8f",x"adf7",x"ad60",x"acc9",x"ac33",x"ab9e",
      x"ab09",x"aa75",x"a9e1",x"a94e",x"a8bc",x"a82a",x"a799",x"a708",x"a678",x"a5e8",x"a559",x"a4cb",x"a43d",x"a3b0",x"a323",x"a297",
      x"a20b",x"a180",x"a0f6",x"a06c",x"9fe2",x"9f59",x"9ed1",x"9e49",x"9dc2",x"9d3b",x"9cb4",x"9c2f",x"9ba9",x"9b25",x"9aa0",x"9a1c",
      x"9999",x"9916",x"9894",x"9812",x"9791",x"9710",x"968f",x"960f",x"9590",x"9511",x"9492",x"9414",x"9397",x"931a",x"929d",x"9221",
      x"91a5",x"9129",x"90af",x"9034",x"8fba",x"8f40",x"8ec7",x"8e4f",x"8dd6",x"8d5e",x"8ce7",x"8c70",x"8bf9",x"8b83",x"8b0d",x"8a98",
      x"8a23",x"89ae",x"893a",x"88c6",x"8853",x"87e0",x"876d",x"86fb",x"8689",x"8618",x"85a7",x"8536",x"84c6",x"8456",x"83e7",x"8377",
      x"8309",x"829a",x"822c",x"81bf",x"8151",x"80e4",x"8078",x"800c",x"7fa0",x"7f34",x"7ec9",x"7e5e",x"7df4",x"7d8a",x"7d20",x"7cb6",
      x"7c4d",x"7be5",x"7b7c",x"7b14",x"7aac",x"7a45",x"79de",x"7977",x"7911",x"78ab",x"7845",x"77df",x"777a",x"7715",x"76b1",x"764d",
      x"75e9",x"7585",x"7522",x"74bf",x"745d",x"73fa",x"7398",x"7337",x"72d5",x"7274",x"7213",x"71b3",x"7152",x"70f2",x"7093",x"7033",
      x"6fd4",x"6f76",x"6f17",x"6eb9",x"6e5b",x"6dfd",x"6da0",x"6d43",x"6ce6",x"6c8a",x"6c2d",x"6bd1",x"6b76",x"6b1a",x"6abf",x"6a64",
      x"6a09",x"6955",x"68a1",x"67ef",x"673e",x"668d",x"65de",x"6530",x"6482",x"63d6",x"632b",x"6280",x"61d7",x"612e",x"6087",x"5fe0",
      x"5f3a",x"5e95",x"5df1",x"5d4e",x"5cac",x"5c0b",x"5b6b",x"5acb",x"5a2c",x"598f",x"58f2",x"5855",x"57ba",x"5720",x"5686",x"55ed",
      x"5555",x"54be",x"5427",x"5391",x"52fc",x"5268",x"51d5",x"5142",x"50b0",x"501f",x"4f8e",x"4efe",x"4e6f",x"4de1",x"4d53",x"4cc6",
      x"4c3a",x"4baf",x"4b24",x"4a9a",x"4a10",x"4987",x"48ff",x"4878",x"47f1",x"476b",x"46e5",x"4660",x"45dc",x"4558",x"44d5",x"4453",
      x"43d1",x"434f",x"42cf",x"424f",x"41cf",x"4151",x"40d2",x"4055",x"3fd8",x"3f5b",x"3edf",x"3e64",x"3de9",x"3d6e",x"3cf5",x"3c7c",
      x"3c03",x"3b8b",x"3b13",x"3a9c",x"3a26",x"39b0",x"393a",x"38c5",x"3851",x"37dd",x"3769",x"36f6",x"3684",x"3612",x"35a0",x"352f",
      x"34bf",x"344f",x"33df",x"3370",x"3302",x"3293",x"3226",x"31b9",x"314c",x"30df",x"3074",x"3008",x"2f9d",x"2f33",x"2ec8",x"2e5f",
      x"2df6",x"2d8d",x"2d24",x"2cbc",x"2c55",x"2bee",x"2b87",x"2b21",x"2abb",x"2a55",x"29f0",x"298b",x"2927",x"28c3",x"2860",x"27fd",
      x"279a",x"2738",x"26d6",x"2674",x"2613",x"25b2",x"2552",x"24f2",x"2492",x"2432",x"23d3",x"2375",x"2317",x"22b9",x"225b",x"21fe",
      x"21a1",x"2145",x"20e8",x"208d",x"2031",x"1fd6",x"1f7b",x"1f21",x"1ec7",x"1e6d",x"1e13",x"1dba",x"1d61",x"1d09",x"1cb1",x"1c59",
      x"1c01",x"1baa",x"1b53",x"1afc",x"1aa6",x"1a50",x"19fa",x"19a5",x"1950",x"18fb",x"18a7",x"1853",x"17ff",x"17ab",x"1758",x"1705",
      x"16b2",x"1660",x"160d",x"15bc",x"156a",x"1519",x"14c8",x"1477",x"1426",x"13d6",x"1386",x"1337",x"12e7",x"1298",x"1249",x"11fb",
      x"11ac",x"115e",x"1111",x"10c3",x"1076",x"1029",x"0fdc",x"0f8f",x"0f43",x"0ef7",x"0eab",x"0e60",x"0e15",x"0dca",x"0d7f",x"0d34",
      x"0cea",x"0ca0",x"0c56",x"0c0c",x"0bc3",x"0b7a",x"0b31",x"0ae8",x"0aa0",x"0a58",x"0a10",x"09c8",x"0981",x"0939",x"08f2",x"08ab",
      x"0865",x"081e",x"07d8",x"0792",x"074d",x"0707",x"06c2",x"067d",x"0638",x"05f3",x"05af",x"056a",x"0526",x"04e2",x"049f",x"045b",
      x"0418",x"03d5",x"0392",x"0350",x"030d",x"02cb",x"0289",x"0247",x"0206",x"01c4",x"0183",x"0142",x"0101",x"00c0",x"0080",x"0040"
   );  
   attribute ramstyle : string;
   attribute ramstyle of divtable : signal is "M10K";
  
begin 

   process (clk1x)
   begin
      if (rising_edge(clk1x)) then
      
         data <= divtable(to_integer(address));
         
      end if;
   end process;
   
end architecture;





