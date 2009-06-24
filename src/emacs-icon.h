/* XPM */
/* Emacs icon

Copyright (C) 2008, 2009  Free Software Foundation, Inc.

Author:  Kentaro Ohkouchi <nanasess@fsm.ne.jp>

This file is part of GNU Emacs.

GNU Emacs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.  */

/* Note that the GTK port uses gdk to display the icon, so Emacs need
   not have XPM support compiled in.  */
#if (defined (HAVE_XPM) && defined (HAVE_X_WINDOWS)) || defined (USE_GTK)
static char * gnu_xpm_bits[] = {
/* width height ncolors chars_per_pixel */
"32 32 255 2",
/* colors */
"AA c #FFFFFFFFFFFF",
"BA c #58585454A9A9",
"CA c #181817175757",
"DA c #393937377777",
"EA c #5E5E5A5AACAC",
"FA c #7E7E7E7E8C8C",
"GA c #73737171B7B7",
"HA c #393936368787",
"IA c #EEEEEEEEF7F7",
"JA c #010101013939",
"KA c #7E7E7C7CBCBC",
"LA c #78787575B9B9",
"MA c #57575252ABAB",
"NA c #9E9E9D9DCDCD",
"OA c #76767474B8B8",
"PA c #86868484C1C1",
"AB c #EDEDECECF6F6",
"BB c #54545151A5A5",
"CB c #4D4D4A4A9A9A",
"DB c #F4F4F4F4FAFA",
"EB c #96969494C9C9",
"FB c #222222225353",
"GB c #8C8C8C8C9595",
"HB c #6A6A6868B2B2",
"IB c #D2D2D1D1E8E8",
"JB c #F0F0F0F0F7F7",
"KB c #3E3E3D3D6C6C",
"LB c #CECECECEE6E6",
"MB c #ADADABABD6D6",
"NB c #91918F8FC6C6",
"OB c #5D5D5A5AACAC",
"PB c #E8E8E8E8F4F4",
"AC c #959595959999",
"BC c #252526266868",
"CC c #555555557D7D",
"DC c #5B5B5858ABAB",
"EC c #7B7B7878BBBB",
"FC c #DDDDDDDDEEEE",
"GC c #55555151ACAC",
"HC c #F0F0F1F1F8F8",
"IC c #111111115252",
"JC c #88888686C2C2",
"KC c #5A5A5858AAAA",
"LC c #60605D5DB1B1",
"MC c #8D8D8A8AC4C4",
"NC c #7C7C7A7ABBBB",
"OC c #E4E4E4E4F5F5",
"PC c #9A9A9898CBCB",
"AD c #F7F7F6F6FAFA",
"BD c #98989696C9C9",
"CD c #F3F3F2F2F9F9",
"DD c #ECECECECF5F5",
"ED c #CACAC9C9E3E3",
"FD c #53534E4EA9A9",
"GD c #8E8E8C8CC5C5",
"HD c #A2A2A1A1CFCF",
"ID c #67676464B0B0",
"JD c #64646161AEAE",
"KD c #9D9D9B9BCCCC",
"LD c #58585454ABAB",
"MD c #6B6B6969B2B2",
"ND c #92929090C7C7",
"OD c #6E6E6C6CB4B4",
"PD c #6C6C6C6C8383",
"AE c #ECECEAEAF5F5",
"BE c #E8E8E8E8F3F3",
"CE c #2C2C2C2C5050",
"DE c #63636060AFAF",
"EE c #7A7A7979BABA",
"FE c #A7A7A5A5D1D1",
"GE c #60605E5EADAD",
"HE c #8A8A8989C3C3",
"IE c #B2B2B1B1D7D7",
"JE c #69696666B5B5",
"KE c #E8E8E7E7F3F3",
"LE c #BCBCBBBBDCDC",
"ME c #DBDBDADAEDED",
"NE c #C0C0BFBFDFDF",
"OE c #2C2C29297777",
"PE c #B4B4B3B3D8D8",
"AF c #66666363B0B0",
"BF c #73737171BABA",
"CF c #83838181BFBF",
"DF c #3E3E3C3C8585",
"EF c #80807E7EBDBD",
"FF c #616161618383",
"GF c #70706F6FB5B5",
"HF c #88888787C6C6",
"IF c #DCDCDBDBEDED",
"JF c #62625F5FAEAE",
"KF c #72726F6FB6B6",
"LF c #D1D1D0D0E8E8",
"MF c #8B8B8888C4C4",
"NF c #6C6C6A6AB3B3",
"OF c #5A5A5656ACAC",
"PF c #C5C5C4C4E1E1",
"AG c #A1A19F9FCFCF",
"BG c #85858383C0C0",
"CG c #80807E7EBEBE",
"DG c #BEBEBDBDDEDE",
"EG c #61615E5EAFAF",
"FG c #57575353A9A9",
"GG c #313131315C5C",
"HG c #292928285959",
"IG c #6E6E6B6BB5B5",
"JG c #55555050ABAB",
"KG c #E9E9E9E9F4F4",
"LG c #404040406D6D",
"MG c #68686464B1B1",
"NG c #E4E4E4E4F2F2",
"OG c #94949292C8C8",
"PG c #D6D6D4D4E9E9",
"AH c #1D1D1D1D5D5D",
"BH c #D5D5D4D4E9E9",
"CH c #50504C4CA6A6",
"DH c #57575353AAAA",
"EH c #71716E6EB6B6",
"FH c #090909093F3F",
"GH c #61615D5DAFAF",
"HH c #8A8A8787C3C3",
"IH c #7F7F7D7DBDBD",
"JH c #6C6C6868B4B4",
"KH c #6A6A6767B2B2",
"LH c #69696666B2B2",
"MH c #5A5A5656A9A9",
"NH c #56565151ABAB",
"OH c #5B5B5757AAAA",
"PH c #5A5A5656AAAA",
"AI c #5D5D5A5AABAB",
"BI c #5E5E5C5CACAC",
"CI c #5A5A5757AAAA",
"DI c #5F5F5C5CACAC",
"EI c #5F5F5C5CADAD",
"FI c #5F5F5D5DADAD",
"GI c #EBEBEBEBF6F6",
"HI c #59595555A9A9",
"II c #B3B3B2B2D8D8",
"JI c #EAEAEAEAF4F4",
"KI c #E6E6E6E6F4F4",
"LI c #F1F1F1F1F8F8",
"MI c #5F5F5D5DAEAE",
"NI c #E7E7E7E7F3F3",
"OI c #57575454A9A9",
"PI c #F4F4F4F4F9F9",
"AJ c #5C5C5757ADAD",
"BJ c #75757373B8B8",
"CJ c #70706C6CB5B5",
"DJ c #9B9B9A9ACBCB",
"EJ c #FAFAFAFAFCFC",
"FJ c #E7E7E6E6F3F3",
"GJ c #81817F7FBEBE",
"HJ c #EBEBEAEAF4F4",
"IJ c #EBEBEAEAF5F5",
"JJ c #E6E6E6E6F2F2",
"KJ c #EEEEEDEDF6F6",
"LJ c #E2E2E2E2F1F1",
"MJ c #EEEEEEEEF4F4",
"NJ c #E2E2E2E2EFEF",
"OJ c #4C4C4B4B8989",
"PJ c #E5E5E4E4F2F2",
"AK c #484848487474",
"BK c #C2C2C1C1DFDF",
"CK c #7A7A7777BBBB",
"DK c #3F3F3E3E7D7D",
"EK c #EDEDEEEEF6F6",
"FK c #68686666B1B1",
"GK c #65656262AFAF",
"HK c #69696565B3B3",
"IK c #E3E3E2E2F1F1",
"JK c #E3E3E3E3F1F1",
"KK c #D4D4D2D2E8E8",
"LK c #9B9B9A9AB7B7",
"MK c #404040407878",
"NK c #D8D8D8D8EBEB",
"OK c #DFDFDEDEEFEF",
"PK c #63636060B2B2",
"AL c #F4F4F3F3FAFA",
"BL c #5A5A5858A5A5",
"CL c #66666464B5B5",
"DL c #8F8F8D8DC8C8",
"EL c #F7F7F5F5FAFA",
"FL c #5C5C5959ACAC",
"GL c #5C5C5757B1B1",
"HL c #B8B8B7B7DADA",
"IL c #5E5E5B5BACAC",
"JL c #41413F3F8C8C",
"KL c #8B8B8A8AC3C3",
"LL c #7F7F7E7EB9B9",
"ML c #A0A0A0A0A1A1",
"NL c #6B6B6A6A8C8C",
"OL c #626261619C9C",
"PL c #71716F6FB5B5",
"AM c #55555252A7A7",
"BM c #C8C8C7C7E3E3",
"CM c #3E3E3E3E5A5A",
"DM c #81817F7FC2C2",
"EM c #52524F4F9797",
"FM c #93939191C8C8",
"GM c #5B5B58589F9F",
"HM c #85858484BCBC",
"IM c #D1D1CFCFE7E7",
"JM c #515150508484",
"KM c #F8F8F7F7FBFB",
"LM c #70706D6DB6B6",
"MM c #50504F4F7878",
"NM c #9B9B9999CCCC",
"OM c #5E5E5B5BB0B0",
"PM c #62625F5FADAD",
"AN c #B7B7B7B7DADA",
"BN c #31312F2F7A7A",
"CN c #484848487A7A",
"DN c #67676565B1B1",
"EN c #FCFCFCFCFDFD",
"FN c #FDFDFCFCFFFF",
"GN c #BBBBBABADCDC",
"HN c #656566667F7F",
"IN c #5A5A5656ABAB",
"JN c #A8A8A7A7D4D4",
"KN c #F8F8F8F8FBFB",
"LN c #95959292C8C8",
"MN c #D9D9D7D7EBEB",
"NN c #303030305454",
"ON c #CBCBCACADADA",
"PN c #363637376363",
"AO c #3B3B3B3B6868",
"BO c #444442428181",
"CO c #434340408D8D",
"DO c #ABABA9A9D4D4",
"EO c #AEAEADADD5D5",
"FO c #5E5E5E5E8484",
"GO c #7E7E7B7BC1C1",
"HO c #9C9C9A9ACCCC",
"IO c #D6D6D5D5EAEA",
"JO c #87878484C1C1",
"KO c #5C5C5858AEAE",
"LO c #89898787C2C2",
"MO c #EAEAEAEAF5F5",
"NO c #C2C2C1C1E0E0",
"OO c #A3A3A3A3D0D0",
"PO c #A5A5A3A3D0D0",
"AP c #70706E6EB9B9",
"BP c #64646161B1B1",
"CP c #6F6F6C6CB8B8",
"DP c #64646161B4B4",
"EP c #D7D7D6D6EBEB",
"FP c #4D4D4848A7A7",
"GP c #ECECEBEBF5F5",
"HP c #E6E6E5E5F2F2",
"IP c #F8F8F8F8FDFD",
"JP c #F9F9FAFAFCFC",
"KP c #FAFAF9F9FCFC",
"LP c #99999898CBCB",
"MP c #EAEAE9E9F6F6",
"NP c #5C5C5959ABAB",
"OP s bg c None",
/* pixels */
"OPOPOPOPOPOPOPOPOPOPOPOPNHNHGCGCGCJGGCGCOPOPOPOPOPOPOPOPOPOPOPOP",
"OPOPOPOPOPOPOPOPOPMAMANHMADHOFAJKOAJOFDHJGJGGCOPOPOPOPOPOPOPOPOP",
"OPOPOPOPOPOPOPMAMAMAMAHIILAFJHCJEHLMIGHKGHLDFDFDNHOPOPOPOPOPOPOP",
"OPOPOPOPOPOPDHFGOIHIILIDCJOAECKAGJHHMCMCMFJOCKGHFPFDOPOPOPOPOPOP",
"OPOPOPOPOPDHFGBAOHJFMDKFLAIHBGJCGDFELELFJKPIELFJMBAJFDOPOPOPOPOP",
"OPOPOPOPBAHIHIDCDEJHLANDHOPCLNNBGDMFLOHHGDAGMNKMAADGFDNHOPOPOPOP",
"OPOPOPBABAHIDCJFKHKAIMKJKJDDKEFCKKBMDGPEDOHDEDCDLIDBCKCHMAOPOPOP",
"OPOPBAHIHIOHEILHCJNBGPIJMOABJBADEJEJKPJPKMADDBIAJBDBKACHDHMAOPOP",
"OPOPHIHIPHDCJFCJCKCFIBIAMPDDKGNKIBIBPGMELJJILIDBDBNEEIFGFGMAOPOP",
"OPHIHIPHPHAIAFKFKAGJAGKGKJIALEBDHOPCBDEBLNEBNAPONDAFDCMHBAGLCBOP",
"OPHIPHCICIILDNGAKAJOJCEOJIJBIONALPKDBDNDKLCFCKIGJDDIOBINOMHAMMAC",
"HIPHCIOHDCILAFKFNCBGKLMCMBNIPIIFFENBNDGDJCEFOANFGKGEILLCOEGGMLKB",
"PHCIOHDCDCOBDEIGLAIHBGLOJCKDEPALKGIIPACFIHBJNFMGJDEGPKOEHGACAOHA",
"PHOHDCNPNPOBOBMIMDNCMCBDDJEBLNGNLJGINENCIGODHBIDGKCLBNHGGBGGOEOM",
"PHOHDCNPNPAMMDKDPFIFPJKIKIHPOKLBLBOKKGLBCFGKKHDNJEHAGGFANNAHOMHI",
"CIDCNPNPFGFMNGDBLIGIPBFJKGDDABIAGIKEJJAEIKPCDNJEJLGGFACEICINAJBA",
"OHDCNPAMJCALDBEKGPJIDDLIPJEDIIFEHDNALPNDNBKLCPGMAOPDCEFHBBOMHIHI",
"OHNPAIBBPELIBEABIAJBIAIIIHODNFNFNFNFHBKHAFJEBLCNFACMJACBLCCIPHHI",
"DCDCAIAMPCDDJKKIDDLIDJGEHBPLBJOALALABJKFKFJDMKPDNNFBEMLCDCOHPHHI",
"DCNPNPDCPMPFIJLJJJHJCGJDKFLAECEENCNCEEECBFDKNLPNJACODPNPDCOHPHOP",
"OPNPAIILPHDNNENIIKPBIOHEKFGANCGJGJGJGJDMBOFFAKJADFCLOBNPDCOHPHOP",
"OPNPAIEADIKCEINMMEBEGIKEEDOOLOKAKAIHHFOJCCCCJADKAPJFAINPDCOHPHOP",
"OPOPNPILILFIILOIKFIIOKKJHCLIKELFHLMBOLLGFOJADAGOEHIDILNPDCOHOPOP",
"OPOPNPOBILDIFIGEJFMDGDLEIFHJCDKNAAONLGCCFHAKJCGAPLLHEANPDCOHOPOP",
"OPOPOPOBILDIEIGEMDLAKABGNBHDIENOPGCCAOFHMMIPMPPELAGENPNPDCOPOPOP",
"OPOPOPAIOBBIDIGEEHBGNBBDNANAHDJNJMHNFBLGMJFNENAANMAMNPDCOPOPOPOP",
"OPOPOPOPOBILBIILNFLOHDANPFLBOCLKFBFHFFNJKIBHBKOGJFDCNPOPOPOPOPOP",
"OPOPOPOPOPILILBIILGEHBOAGJMCHMHGFHAHLLDLKAPLBIAMNPNPOPOPOPOPOPOP",
"OPOPOPOPOPOPOPILBIBIFIDEFKBFDAJAAHGFBFIDJFOBFLOBAIOPOPOPOPOPOPOP",
"OPOPOPOPOPOPOPOPILILBIILPKCBJAAHJFBPILILOBOBAIOPOPOPOPOPOPOPOPOP",
"OPOPOPOPOPOPOPOPOPOPILMIGECABCPKGHAIILOBOBOPOPOPOPOPOPOPOPOPOPOP",
"OPOPOPOPOPOPOPOPOPOPOPOPOPCAOPOPOPOPOPOPOPOPOPOPOPOPOPOPOPOPOPOP"};
#endif /* (defined (HAVE_XPM) && defined (HAVE_X_WINDOWS)) || defined (USE_GTK) */

#define gnu_xbm_width 50
#define gnu_xbm_height 50
static unsigned char gnu_xbm_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xe0, 0x01, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x80, 0x03, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x0e,
   0x00, 0x00, 0x0c, 0x00, 0x70, 0x00, 0x1e, 0x00, 0x00, 0x06, 0xc0, 0xdd,
   0x01, 0x34, 0x00, 0x00, 0x07, 0x3c, 0x07, 0x03, 0x34, 0x00, 0x80, 0x03,
   0x1f, 0x06, 0x06, 0x24, 0x00, 0x80, 0x03, 0x0f, 0x04, 0x0c, 0x26, 0x00,
   0xc0, 0x81, 0x07, 0x00, 0x08, 0x33, 0x00, 0x60, 0xc1, 0xe3, 0x80, 0xbb,
   0x31, 0x00, 0x30, 0xe1, 0x33, 0xfe, 0xff, 0x18, 0x00, 0x10, 0xf1, 0x31,
   0xc7, 0xe3, 0x1f, 0x00, 0x10, 0xf1, 0xd8, 0x01, 0x05, 0x3c, 0x00, 0x10,
   0x83, 0x6c, 0x00, 0x1a, 0x40, 0x00, 0x10, 0x66, 0x36, 0x54, 0xd5, 0xff,
   0x00, 0x30, 0x3c, 0xdb, 0xab, 0x3a, 0x2a, 0x00, 0x60, 0x80, 0xe9, 0x54,
   0x35, 0x00, 0x00, 0xe0, 0xe0, 0x6c, 0xb9, 0x6a, 0x00, 0x00, 0x80, 0x37,
   0xb6, 0x66, 0x75, 0x00, 0x00, 0x00, 0x0f, 0xb6, 0xb4, 0x6a, 0x00, 0x00,
   0x00, 0x06, 0xb3, 0x77, 0x75, 0x00, 0x00, 0x00, 0xe1, 0x19, 0xa7, 0x6a,
   0x00, 0x00, 0xc0, 0xff, 0x19, 0x48, 0xf5, 0x00, 0x00, 0x40, 0x75, 0x15,
   0xaf, 0xea, 0x00, 0x00, 0x00, 0x70, 0x35, 0x66, 0xd5, 0x00, 0x00, 0x00,
   0x58, 0x6a, 0x80, 0xea, 0x00, 0x00, 0x00, 0xdc, 0xaa, 0x80, 0xd5, 0x01,
   0x00, 0x00, 0x9c, 0x27, 0x03, 0xeb, 0x01, 0x00, 0x00, 0xbc, 0x65, 0x04,
   0xd4, 0x01, 0x00, 0x00, 0x3c, 0x55, 0xed, 0x6b, 0x03, 0x00, 0x00, 0x3e,
   0xcd, 0x2a, 0x3e, 0x02, 0x00, 0x00, 0x7e, 0xb9, 0x2a, 0xb8, 0x03, 0x00,
   0x00, 0x7c, 0x93, 0x3d, 0x91, 0x03, 0x00, 0x00, 0x7c, 0x76, 0x77, 0x96,
   0x01, 0x00, 0x00, 0xf8, 0x6d, 0xf6, 0xc4, 0x01, 0x00, 0x00, 0xf8, 0xdd,
   0xfe, 0xc3, 0x01, 0x00, 0x00, 0xf0, 0xb1, 0xfd, 0xfc, 0x01, 0x00, 0x00,
   0xd0, 0x2f, 0xe7, 0xc1, 0x00, 0x00, 0x00, 0xc0, 0x4f, 0xe6, 0x61, 0x00,
   0x00, 0x00, 0x80, 0xff, 0xf6, 0x7f, 0x00, 0x00, 0x00, 0x80, 0xfe, 0x1c,
   0x3e, 0x00, 0x00, 0x00, 0x00, 0xfa, 0x1f, 0x00, 0x00, 0x00, 0x00, 0x00,
   0xf8, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00, 0xa0, 0x02, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00};

/* arch-tag: b57020c7-c937-4d77-8ca6-3875178d9828
   (do not change this comment) */
