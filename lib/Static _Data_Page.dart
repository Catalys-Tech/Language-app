
// ------------------------- Static Data -------------------------
import 'main.dart';

const List<String> englishLetters = ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z'];

final Map<String, List<String>> wordsMapEnglish = {
  'A': ['Apple','Ant','Airplane','Arm','Arrow','Axe','Animal','Acorn'],
  'B': ['Ball','Book','Bird','Box','Boy','Butterfly','Bread','Bear'],
  'C': ['Cat','Car','Cup','Cake','Cloud','Crab','Candle','Chair'],
  'D': ['Dog','Door','Duck','Drum','Desk','Doll','Diamond','Dragon'],
  'E': ['Elephant','Egg','Eagle','Ear','Engine','Earth','Eye','Elbow'],
  'F': ['Fish','Fox','Fan','Flag','Flower','Frog','Finger','Feather'],
  'G': ['Goat','Guitar','Girl','Glass','Garden','Gate','Goose','Glove'],
  'H': ['Hat','Horse','House','Hand','Heart','Hammer','Hill','Hose'],
  'I': ['Ice','Insect','Igloo','Ink','Island','Iron','Idea','Ivy'],
  'J': ['Jar','Juice','Jelly','Jump','Jacket','Jaguar','Jam','Jewel'],
  'K': ['Kite','King','Key','Koala','Knife','Kitten','Kangaroo','Kiwi'],
  'L': ['Lion','Lamp','Leaf','Letter','Lemon','Ladder','Lake','Leg'],
  'M': ['Monkey','Moon','Mouse','Milk','Map','Mountain','Mango','Mirror'],
  'N': ['Nest','Nose','Net','Notebook','Needle','Necklace','Nut','Night'],
  'O': ['Owl','Orange','Ocean','Octopus','Onion','Oven','Oil','Orbit'],
  'P': ['Parrot','Pen','Pencil','Pumpkin','Pear','Pillow','Pot','Plant'],
  'Q': ['Queen','Quill','Quilt','Question','Quokka','Quartz','Quarry','Quiver'],
  'R': ['Rabbit','Rain','Ring','Rose','Robot','River','Rocket','Roof'],
  'S': ['Sun','Snake','Star','Spoon','Ship','Sheep','Sock','Sand'],
  'T': ['Tiger','Tree','Table','Tomato','Train','Turtle','Toy','Tent'],
  'U': ['Umbrella','Unicorn','Urn','Uniform','Universe','Utensil','Udon','Urchin'],
  'V': ['Van','Violin','Vase','Vegetable','Volcano','Vulture','Vest','Vine'],
  'W': ['Wolf','Water','Window','Whale','Watch','Wheel','Wing','Worm'],
  'X': ['Xylophone','Xerox','Xenon','Xigua','Xebec','Xyst','Xenops','Xylograph'],
  'Y': ['Yak','Yacht','Yogurt','Yo-yo','Yam','Yard','Yellow','Yawn'],
  'Z': ['Zebra','Zoo','Zipper','Zero','Zucchini','Zephyr','Zone','Zombie'],
};

const List<String> arabicLetters = ['ا','ب','ت','ث','ج','ح','خ','د','ذ','ر','ز','س','ش','ص','ض','ط','ظ','ع','غ','ف','ق','ك','ل','م','ن','ه','و','ي'];

final Map<String, List<String>> wordsMapArabic = {
  'ا': ['أَب, Father, Ab','أُمّ, Mother, Umm','أَرْض, Earth, Ard','أَسَد, Lion, Asad'],
  'ب': ['بَاب, Door, Baab','بَيْت, House, Bayt','بَطّ, Duck, Batt','بَقَرَة, Cow, Baqara'],
  'ت': ['تِين, Fig, Teen','تَمْر, Date, Tamr','تُفَّاح, Apple, Tuffah','تِلمِيذ, Student, Tilmeedh'],
  'ث': ["ثَعْلَب, Fox, Tha'leb",'ثَوْر, Bull, Thawr','ثَلْج, Snow, Thalj','ثَقِيل, Heavy, Thaqeel'],
  'ج': ['جَمَل, Camel, Jamal','جَبَل, Mountain, Jabal','جَرَس, Bell, Jaras','جَوْز, Walnut, Jawz'],
  'ح': ['حِصَان, Horse, Hisan','حَب, Grain, Hubb','حَقِيبَة, Bag, Haqeeba','حِمَار, Donkey, Himar'],
  'خ': ['خُبْز, Bread, Khobz','خَيْمَة, Tent, Khaymah','خَرُوف, Sheep, Kharuf','خَشَب, Wood, Khashab'],
  'د': ['دَرَج, Stairs, Daraj','دَرْس, Lesson, Dars','دَفْتَر, Notebook, Daftar','دَجَاج, Chicken, Dajaj'],
  'ذ': ['ذَهَب, Gold, Dhahab','ذِئْب, Wolf, Dheeb','ذُرَة, Corn, Dhurah','ذِكْر, Remembrance, Dhikr'],
  'ر': ['رَجُل, Man, Rajul','رَمْل, Sand, Raml','رَسُول, Messenger, Rasul','رِيح, Wind, Reeh'],
  'ز': ['زَهْرَة, Flower, Zahrah','زُرَاع, Crops, Zura\'a','زَمِيل, Colleague, Zameel','زُجَاج, Glass, Zujaj'],
  'س': ['سَيَّارَة, Car, Sayyarah','سَمَك, Fish, Samak','سَاعَة, Clock, Sa\'ah','سَمَاء, Sky, Sama\''],
  'ش': ['شَمْس, Sun, Shams','شَجَرَة, Tree, Shajarah','شَاي, Tea, Shay','شِبْل, Cub, Shibl'],
  'ص': ['صَحِيفَة, Newspaper, Sahifah','صَبَاح, Morning, Sabah','صَوْت, Voice, Sawt','صَحْرَاء, Desert, Sahra\'a'],
  'ض': ['ضَوء, Light, Daw','ضَفْدَع, Frog, Dafda\'','ضِرْس, Molar, Dirs','ضَبَاب, Fog, Dabab'],
  'ط': ['طَائِر, Bird, Ta\'ir','طَبِيب, Doctor, Tabeeb','طِين, Clay, Teen','طُرُق, Roads, Turuq'],
  'ظ': ['ظِلّ, Shadow, Zill','ظَرْف, Envelope, Zarf','ظَهْر, Back, Zahr','ظَلَام, Darkness, Zalam'],
  'ع': ['عَيْن, Eye, Ain','عِصَافِير, Birds, Asafir','عَمَل, Work, Amal','عِيد, Festival, Eid'],
  'غ': ['غُرَاب, Crow, Ghurab','غَابَة, Forest, Ghabah','غَذَاء, Food, Ghiza\'','غَيْم, Cloud, Ghaym'],
  'ف': ['فِيل, Elephant, Feel','فَرَس, Horse, Faras','فَاكِهَة, Fruit, Fakihah','فِكْر, Thought, Fikr'],
  'ق': ['قَمَر, Moon, Qamar','قَلَم, Pen, Qalam','قَصْر, Palace, Qasr','قِطّ, Cat, Qitt'],
  'ك': ['كِتَاب, Book, Kitab','كَلْب, Dog, Kalb','كَعْك, Cake, Ka\'k','كُرَة, Ball, Kurah'],
  'ل': ['لَبَن, Milk, Laban','لَيْمُون, Lemon, Laymoon','لَحْم, Meat, Lahm','لُعْبَة, Toy, Lu\'bah'],
  'م': ['مَدْرَسَة, School, Madrasa','مَاء, Water, Ma\'','مِفْتَاح, Key, Miftaah','مَرْحَبًا, Hello, Marhaban'],
  'ن': ['نَجْم, Star, Najm','نَهْر, River, Nahr','نَار, Fire, Nar','نَمْل, Ant, Naml'],
  'ه': ['هَوَاء, Air, Hawa\'','هَاتِف, Phone, Hatif','هِرّ, Cat, Harr','هَدِيف, Goal, Hadeef'],
  'و': ['وَرْد, Flower, Ward','وَجْه, Face, Wajh','وَطَن, Country, Watan','وَلَد, Boy, Walad'],
  'ي': ['يَد, Hand, Yad','يَوْم, Day, Yawm','يَمِين, Right, Yameen','يَسَار, Left, Yasar'],
};

final List<Language> supportedLanguages = [
  Language(
    code: 'en',
    name: 'English',
    letters: englishLetters,
    wordsMap: wordsMapEnglish,
  ),
  Language(
    code: 'ar',
    name: 'Arabic',
    letters: arabicLetters,
    wordsMap: wordsMapArabic,
  ),
];

Map<String, List<String>> getWordsMapForLang(String code) {
  return switch (code) {
    'en' => wordsMapEnglish,
    'ar' => wordsMapArabic,
    _ => throw Exception('Unknown language code: $code'),
  };
}
