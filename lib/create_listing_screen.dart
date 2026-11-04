import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'city_store.dart';
import 'theme.dart';

const _bodyTypes = ['Седан', 'Хэтчбек', 'Универсал', 'Кроссовер', 'Внедорожник', 'Купе', 'Кабриолет', 'Минивэн', 'Пикап'];
const _fuels = ['Бензин', 'Дизель', 'Гибрид', 'Электро', 'Газ/бензин'];
const _gearboxes = ['Автомат', 'Механика', 'Робот', 'Вариатор'];
const _drives = ['Передний', 'Задний', 'Полный'];
const _wheels = ['Левый', 'Правый'];
const _conditions = ['Новый', 'С пробегом'];

/// Справочник авто: марка → модель → поколения (поколения только там, где они известны).
const _carCatalog = <String, Map<String, List<String>>>{
  'Toyota': {
    'Camry': ['XV70', 'XV50', 'XV40', 'XV30'],
    'Corolla': ['E210', 'E180', 'E170', 'E160'],
    'Corolla Cross': [],
    'RAV4': ['XA50', 'XA40', 'XA30'],
    'Land Cruiser': ['300', '200', '100', '80'],
    'Land Cruiser Prado': ['150', '120', '90'],
    'Hilux': ['AN120', 'AN10'],
    'Yaris': [],
    'Crown': [],
    'Harrier': [],
    'Highlander': [],
    'Fortuner': [],
    'Prius': [],
    'Sienna': [],
    'Alphard': [],
    'Vellfire': [],
    'Hiace': [],
    'Probox': [],
    'Premio': [],
    'Allion': [],
    'Avensis': [],
    'Auris': [],
    'Vitz': [],
    'Passo': [],
    'Aqua': [],
    'Ist': [],
    'Verso': [],
    'Wish': [],
    'Noah': [],
    'Voxy': [],
    'Estima': [],
    'FJ Cruiser': [],
    '4Runner': [],
    'Tacoma': [],
    'Tundra': [],
    'Sequoia': [],
    'C-HR': [],
    'bZ4X': [],
    'Mark X': [],
    'Venza': [],
    'Matrix': [],
    'Rush': [],
    'Land Cruiser 70': [],
  },
  'Lexus': {
    'RX': ['AL20', 'AL10', 'XU30'],
    'LX': ['J200', 'J100'],
    'ES': ['XV70', 'XV60'],
    'GX': ['J150', 'J120'],
    'LS': [],
    'IS': [],
    'GS': [],
    'NX': [],
    'UX': [],
    'LC': [],
    'RC': [],
    'CT': [],
    'LM': [],
  },
  'Honda': {
    'Accord': ['X', 'IX', 'VIII'],
    'CR-V': ['RW', 'RT', 'RM'],
    'Civic': ['XI', 'X', 'IX'],
    'Jazz': [],
    'Fit': [],
    'HR-V': [],
    'Pilot': [],
    'Odyssey': [],
    'Stepwgn': [],
    'Stream': [],
    'Crosstour': [],
    'Element': [],
    'Legend': [],
    'Insight': [],
    'City': [],
    'Freed': [],
    'Vezel': [],
  },
  'Nissan': {
    'Qashqai': ['J12', 'J11'],
    'X-Trail': ['T33', 'T32', 'T31'],
    'Patrol': ['Y62', 'Y61'],
    'Almera': [],
    'Sentra': [],
    'Teana': [],
    'Murano': [],
    'Pathfinder': [],
    'Juke': [],
    'Note': [],
    'Tiida': [],
    'Versa': [],
    'Altima': [],
    'Maxima': [],
    'Terrano': [],
    'Navara': [],
    'Pulsar': [],
    'Leaf': [],
    'Serena': [],
    'Elgrand': [],
    'Armada': [],
    'Cefiro': [],
    'Bluebird': [],
    'Sunny': [],
    'Primera': [],
    'X-Terra': [],
    'Kicks': [],
    'Magnite': [],
  },
  'Infiniti': {
    'QX56': [],
    'QX60': [],
    'QX70': [],
    'QX80': [],
    'FX': [],
    'EX': [],
    'G': [],
    'M': [],
    'Q50': [],
    'JX': [],
  },
  'Mitsubishi': {
    'Pajero': ['V90', 'V80'],
    'Outlander': ['GG', 'GF'],
    'L200': [],
    'Pajero Sport': [],
    'Lancer': [],
    'ASX': [],
    'Galant': [],
    'Delica': [],
    'Montero': [],
    'Eclipse Cross': [],
    'Colt': [],
    'Mirage': [],
    'Carisma': [],
    'Space Star': [],
    'Xpander': [],
    'Triton': [],
  },
  'Mazda': {
    'CX-5': ['KF', 'KE'],
    'Mazda 6': ['GJ', 'GH'],
    'Mazda 3': ['BP', 'BM'],
    'CX-7': [],
    'CX-9': [],
    'CX-3': [],
    'CX-30': [],
    'CX-60': [],
    'MX-5': [],
    'Demio': [],
    'Axela': [],
    'Atenza': [],
    'Familia': [],
    'Premacy': [],
    'Biante': [],
    'Tribute': [],
    'Bongo': [],
    'Mazda 2': [],
    'Mazda 5': [],
    'RX-8': [],
    'Verisa': [],
  },
  'Subaru': {
    'Forester': ['SK', 'SJ', 'SH'],
    'Outback': ['BT', 'BR', 'BP'],
    'Legacy': ['BN', 'BM', 'BL'],
    'Impreza': [],
    'XV': [],
    'Levorg': [],
    'WRX': [],
    'Tribeca': [],
    'Exiga': [],
    'Leone': [],
    'Justy': [],
    'BRZ': [],
  },
  'Suzuki': {
    'Vitara': [],
    'Grand Vitara': [],
    'Jimny': [],
    'SX4': [],
    'Swift': [],
    'Baleno': [],
    'Ignis': [],
    'Alto': [],
    'Wagon R': [],
    'Escudo': [],
    'Liana': [],
    'Kizashi': [],
    'Ertiga': [],
    'Solio': [],
    'Every': [],
    'Cultus': [],
    'Splash': [],
  },
  'Daihatsu': {
    'Terios': [],
    'Move': [],
    'Tanto': [],
    'Mira': [],
    'Hijet': [],
    'Rocky': [],
    'Cuore': [],
    'Copen': [],
    'Sirion': [],
    'Boon': [],
    'Atrai': [],
    'YRV': [],
    'Gran Move': [],
  },
  'Isuzu': {
    'D-Max': [],
    'MU-X': [],
    'Trooper': [],
    'Bighorn': [],
    'Elf': [],
    'Gemini': [],
  },
  'Hyundai': {
    'Sonata': ['DN8', 'LF', 'YF'],
    'Elantra': ['CN7', 'AD', 'MD'],
    'Tucson': ['NX4', 'TL', 'LM'],
    'Creta': [],
    'Solaris': [],
    'Santa Fe': [],
    'Grandeur': [],
    'Accent': [],
    'Getz': [],
    'Verna': [],
    'i30': [],
    'i40': [],
    'Palisade': [],
    'Venue': [],
    'Kona': [],
    'Starex': [],
    'H-1': [],
    'Staria': [],
    'Terracan': [],
    'Matrix': [],
    'Trajet': [],
    'Coupe': [],
    'Genesis Coupe': [],
    'Ioniq': [],
    'Ioniq 5': [],
    'Ioniq 6': [],
    'Xcent': [],
    'Porter': [],
    'Universe': [],
  },
  'Kia': {
    'K5': ['DL3'],
    'Sportage': ['NQ5', 'QL', 'SL'],
    'Cerato': ['BD', 'YD'],
    'Rio': [],
    'Optima': [],
    'Seltos': [],
    'Soul': [],
    'Sorento': [],
    'Mohave': [],
    'Carnival': [],
    'Picanto': [],
    'Ceed': [],
    'Forte': [],
    'Stinger': [],
    'Telluride': [],
    'Carens': [],
    'Opirus': [],
    'K8': [],
    'K9': [],
    'Morning': [],
    'Mentor': [],
    'Shuma': [],
    'Sephia': [],
    'Spectra': [],
    'Pride': [],
    'Venga': [],
    'Bongo': [],
    'EV6': [],
    'EV9': [],
    'Niro': [],
    'Retona': [],
  },
  'Genesis': {
    'G70': [],
    'G80': [],
    'G90': [],
    'GV70': [],
    'GV80': [],
    'GV60': [],
  },
  'Chevrolet': {
    'Cruze': [],
    'Malibu': [],
    'Lacetti': [],
    'Captiva': [],
    'Niva': [],
    'Aveo': [],
    'Epica': [],
    'Tahoe': [],
    'Suburban': [],
    'Traverse': [],
    'Equinox': [],
    'Trailblazer': [],
    'Blazer': [],
    'Camaro': [],
    'Corvette': [],
    'Spark': [],
    'Matiz': [],
    'Orlando': [],
    'Cobalt': [],
    'Onix': [],
    'Tracker': [],
    'Colorado': [],
    'Silverado': [],
    'Express': [],
    'Lanos': [],
    'Nubira': [],
    'Rezzo': [],
    'Kalos': [],
    'Monte Carlo': [],
    'Impala': [],
    'Volt': [],
    'Bolt': [],
    'Avalanche': [],
    'Uplander': [],
    'HHR': [],
  },
  'Cadillac': {
    'Escalade': [],
    'CTS': [],
    'SRX': [],
    'XT5': [],
    'XT6': [],
    'ATS': [],
    'DTS': [],
    'Seville': [],
    'Eldorado': [],
    'CT5': [],
    'CT4': [],
    'XTS': [],
  },
  'Buick': {
    'Enclave': [],
    'Encore': [],
    'LaCrosse': [],
    'Regal': [],
    'Verano': [],
    'Envision': [],
    'Rendezvous': [],
    'Park Avenue': [],
    'Lucerne': [],
    'Century': [],
    'Electra': [],
    'Riviera': [],
    'Terraza': [],
  },
  'GMC': {
    'Yukon': [],
    'Sierra': [],
    'Terrain': [],
    'Acadia': [],
    'Canyon': [],
    'Envoy': [],
    'Savana': [],
    'Jimmy': [],
    'Denali': [],
  },
  'Ford': {
    'Focus': ['III', 'II'],
    'Kuga': [],
    'Mondeo': [],
    'Explorer': [],
    'Fiesta': [],
    'Mustang': [],
    'Escape': [],
    'Edge': [],
    'Expedition': [],
    'F-150': [],
    'Ranger': [],
    'Transit': [],
    'Connect': [],
    'Galaxy': [],
    'S-Max': [],
    'C-Max': [],
    'B-Max': [],
    'Ecosport': [],
    'Bronco': [],
    'Taurus': [],
    'Fusion': [],
    'Puma': [],
    'Maverick': [],
    'Territory': [],
    'Everest': [],
    'Kuga Hybrid': [],
  },
  'Lincoln': {
    'Navigator': [],
    'Aviator': [],
    'Town Car': [],
    'MKZ': [],
    'MKX': [],
    'Continental': [],
    'Corsair': [],
    'Nautilus': [],
    'Zephyr': [],
  },
  'Jeep': {
    'Grand Cherokee': [],
    'Cherokee': [],
    'Wrangler': [],
    'Compass': [],
    'Renegade': [],
    'Patriot': [],
    'Liberty': [],
    'Commander': [],
    'Wagoneer': [],
    'Gladiator': [],
    'Grand Commander': [],
  },
  'Dodge': {
    'Charger': [],
    'Challenger': [],
    'Durango': [],
    'Journey': [],
    'Caliber': [],
    'Nitro': [],
    'Ram': [],
    'Caravan': [],
    'Avenger': [],
    'Dakota': [],
    'Magnum': [],
    'Viper': [],
    'Stratus': [],
    'Intrepid': [],
  },
  'Chrysler': {
    '300C': [],
    'Voyager': [],
    'Pacifica': [],
    'Sebring': [],
    'Pt Cruiser': [],
    'Crossfire': [],
    'Aspen': [],
    'Town & Country': [],
  },
  'Mercedes-Benz': {
    'E-Class': ['W213', 'W212', 'W211'],
    'C-Class': ['W206', 'W205', 'W204'],
    'S-Class': ['W223', 'W222', 'W221'],
    'G-Class': ['W463'],
    'A-Class': [],
    'B-Class': [],
    'CLA': [],
    'CLS': [],
    'GLA': [],
    'GLB': [],
    'GLC': [],
    'GLE': [],
    'GLS': [],
    'GL': [],
    'GLK': [],
    'ML': [],
    'M-Class': [],
    'R-Class': [],
    'SL': [],
    'SLK': [],
    'SLC': [],
    'AMG GT': [],
    'Vito': [],
    'Viano': [],
    'Sprinter': [],
    'Citan': [],
    'Metris': [],
    'V-Class': [],
    'Maybach': [],
    'EQS': [],
    'EQE': [],
    'EQC': [],
    'CL': [],
    'CLK': [],
    'SLS': [],
  },
  'BMW': {
    '3 Series': ['G20', 'F30', 'E90'],
    '5 Series': ['G30', 'F10', 'E60'],
    'X5': ['G05', 'F15', 'E70'],
    'X6': ['G06', 'F16'],
    '1 Series': [],
    '2 Series': [],
    '4 Series': [],
    '6 Series': [],
    '7 Series': [],
    '8 Series': [],
    'X1': [],
    'X2': [],
    'X3': [],
    'X4': [],
    'X7': [],
    'Z3': [],
    'Z4': [],
    'M3': [],
    'M5': [],
    'i3': [],
    'i4': [],
    'i7': [],
    'iX': [],
    'iX3': [],
    'M-Class': [],
  },
  'Audi': {
    'A6': ['C8', 'C7', 'C6'],
    'A4': ['B9', 'B8'],
    'Q7': ['4M', '4L'],
    'A1': [],
    'A3': [],
    'A5': [],
    'A7': [],
    'A8': [],
    'Q2': [],
    'Q3': [],
    'Q5': [],
    'Q8': [],
    'TT': [],
    'R8': [],
    'RS6': [],
    'RS7': [],
    'S4': [],
    'S6': [],
    'S8': [],
    'e-tron': [],
    '100': [],
    '80': [],
    'Allroad': [],
  },
  'Volkswagen': {
    'Passat': ['B8', 'B7', 'B6'],
    'Golf': ['VII', 'VI', 'V'],
    'Tiguan': ['II', 'I'],
    'Polo': [],
    'Jetta': [],
    'Touareg': [],
    'Touran': [],
    'Sharan': [],
    'Caddy': [],
    'Caravelle': [],
    'Multivan': [],
    'Transporter': [],
    'Amarok': [],
    'Arteon': [],
    'Bora': [],
    'Vento': [],
    'Lupo': [],
    'Fox': [],
    'Beetle': [],
    'Scirocco': [],
    'Eos': [],
    'Phaeton': [],
    'Teramont': [],
    'ID.4': [],
    'ID.3': [],
    'T-Roc': [],
    'T-Cross': [],
    'Taos': [],
    'Atlas': [],
    'Gol': [],
    'Santana': [],
    'Jetta VS5': [],
    'Crafter': [],
  },
  'Skoda': {
    'Octavia': [],
    'Fabia': [],
    'Superb': [],
    'Rapid': [],
    'Yeti': [],
    'Kodiaq': [],
    'Karoq': [],
    'Kamiq': [],
    'Roomster': [],
    'Felicia': [],
    'Favorit': [],
    'Felicia Pickup': [],
    'Octavia Scout': [],
    'Enyaq': [],
    'Citigo': [],
  },
  'Seat': {
    'Leon': [],
    'Ibiza': [],
    'Toledo': [],
    'Altea': [],
    'Cordoba': [],
    'Alhambra': [],
    'Arona': [],
    'Ateca': [],
    'Tarraco': [],
    'Exeo': [],
    'Marbella': [],
  },
  'Opel': {
    'Astra': [],
    'Corsa': [],
    'Vectra': [],
    'Insignia': [],
    'Zafira': [],
    'Meriva': [],
    'Mokka': [],
    'Crossland': [],
    'Grandland': [],
    'Antara': [],
    'Omega': [],
    'Signum': [],
    'Tigra': [],
    'Agila': [],
    'Frontera': [],
    'Combo': [],
    'Movano': [],
    'Vivaro': [],
    'Adam': [],
    'Kadett': [],
    'Senator': [],
    'Monterey': [],
  },
  'Peugeot': {
    '206': [],
    '207': [],
    '208': [],
    '301': [],
    '307': [],
    '308': [],
    '407': [],
    '408': [],
    '508': [],
    '2008': [],
    '3008': [],
    '4007': [],
    '4008': [],
    '5008': [],
    '107': [],
    '108': [],
    '106': [],
    '405': [],
    '406': [],
    '605': [],
    'Partner': [],
    'Expert': [],
    'Boxer': [],
    'Traveller': [],
    'Rifter': [],
  },
  'Citroen': {
    'C1': [],
    'C2': [],
    'C3': [],
    'C3 Aircross': [],
    'C4': [],
    'C4 Aircross': [],
    'C4 Cactus': [],
    'C5': [],
    'C5 Aircross': [],
    'C6': [],
    'Berlingo': [],
    'Jumper': [],
    'Jumpy': [],
    'Xsara': [],
    'Xantia': [],
    'Picasso': [],
    'C-Elysee': [],
    'DS3': [],
    'DS4': [],
    'DS5': [],
    'Saxo': [],
    'Xsara Picasso': [],
    'Nemo': [],
    'Spacetourer': [],
    'Ami': [],
  },
  'Renault': {
    'Logan': [],
    'Duster': [],
    'Sandero': [],
    'Megane': [],
    'Laguna': [],
    'Fluence': [],
    'Scenic': [],
    'Clio': [],
    'Kangoo': [],
    'Symbol': [],
    'Kaptur': [],
    'Arkana': [],
    'Koleos': [],
    'Captur': [],
    'Espace': [],
    'Safrane': [],
    'Latitude': [],
    'Talisman': [],
    'Trafic': [],
    'Master': [],
    'Dokker': [],
    'Lodgy': [],
    'Twingo': [],
    'Zoe': [],
    'Kadjar': [],
    'Fluence Z.E.': [],
    'Vel Satis': [],
    'Avantime': [],
    'Modus': [],
    'Wind': [],
    'Express': [],
  },
  'Fiat': {
    'Punto': [],
    'Doblo': [],
    'Linea': [],
    'Bravo': [],
    'Stilo': [],
    'Ducato': [],
    'Scudo': [],
    'Tipo': [],
    '500': [],
    '500X': [],
    '500L': [],
    'Panda': [],
    'Albea': [],
    'Palio': [],
    'Siena': [],
    'Seicento': [],
    'Multipla': [],
    'Croma': [],
    'Freemont': [],
    'Fullback': [],
    'Uno': [],
    'Tempra': [],
    'Regata': [],
    'Idea': [],
    'Qubo': [],
    'Sedici': [],
    'Strada': [],
    'Ulysse': [],
    'Coupe': [],
    'Barchetta': [],
    'Marea': [],
    'Brava': [],
    'Ritmo': [],
    'Tipo 2': [],
  },
  'Alfa Romeo': {
    'Giulia': [],
    'Stelvio': [],
    '147': [],
    '156': [],
    '159': [],
    '166': [],
    '164': [],
    'Brera': [],
    'Spider': [],
    'GT': [],
    'Giulietta': [],
    'MiTo': [],
    'Tonale': [],
  },
  'Volvo': {
    'XC90': [],
    'XC60': [],
    'XC40': [],
    'XC70': [],
    'XC30': [],
    'S60': [],
    'S80': [],
    'S90': [],
    'V40': [],
    'V50': [],
    'V60': [],
    'V70': [],
    'V90': [],
    'C30': [],
    'C70': [],
    'S40': [],
    'C40': [],
    'EX30': [],
    'EX90': [],
    '440': [],
    '460': [],
    '480': [],
    '850': [],
    '240': [],
    '740': [],
    '760': [],
    '940': [],
    '960': [],
  },
  'Land Rover': {
    'Range Rover': [],
    'Range Rover Sport': [],
    'Range Rover Evoque': [],
    'Range Rover Velar': [],
    'Discovery': [],
    'Discovery Sport': [],
    'Defender': [],
    'Freelander': [],
    'Discovery 4': [],
    'Discovery 3': [],
  },
  'Jaguar': {
    'XF': [],
    'XE': [],
    'XJ': [],
    'F-Pace': [],
    'E-Pace': [],
    'F-Type': [],
    'XK': [],
    'S-Type': [],
    'X-Type': [],
    'I-Pace': [],
  },
  'Mini': {
    'Cooper': [],
    'Countryman': [],
    'Clubman': [],
    'Paceman': [],
    'Roadster': [],
    'Coupe': [],
    'Cabrio': [],
    'Convertible': [],
  },
  'Porsche': {
    '911': [],
    'Cayenne': [],
    'Macan': [],
    'Panamera': [],
    'Boxster': [],
    'Cayman': [],
    'Taycan': [],
    '918': [],
    'Carrera GT': [],
  },
  'Tesla': {
    'Model S': [],
    'Model 3': [],
    'Model X': [],
    'Model Y': [],
    'Cybertruck': [],
    'Roadster': [],
  },
  'Lada': {
    'Granta': [],
    'Vesta': [],
    'Niva': [],
    'Priora': [],
    '2107': [],
    '2106': [],
    '2105': [],
    '2104': [],
    '2101': [],
    '2108': [],
    '2109': [],
    '2110': [],
    '2111': [],
    '2112': [],
    '2114': [],
    '2115': [],
    'Kalina': [],
    'Largus': [],
    'XRAY': [],
    'Niva Legend': [],
    'Niva Travel': [],
    'Samara': [],
    'Oka': [],
    'Kalina 2': [],
  },
  'UAZ': {
    'Patriot': [],
    'Hunter': [],
    'Pickup': [],
    'Buhanka': [],
    '452': [],
    '469': [],
    '3151': [],
    'Profi': [],
    'Simbir': [],
  },
  'GAZ': {
    'Gazelle': [],
    'Sobol': [],
    'Volga': [],
    'Valdai': [],
    'Next': [],
    '3110': [],
    '31105': [],
    'Gazelle Next': [],
  },
  'ZAZ': {
    'Lanos': [],
    'Sens': [],
    'Forza': [],
    'Vida': [],
    'Chance': [],
  },
  'Daewoo': {
    'Nexia': [],
    'Matiz': [],
    'Lanos': [],
    'Espero': [],
    'Leganza': [],
    'Nubira': [],
    'Tico': [],
    'Damas': [],
    'Labo': [],
    'Gentra': [],
    'Winstorm': [],
    'Lacetti': [],
    'Magnus': [],
    'Kalos': [],
    'Gentra X': [],
    'Rezzo': [],
    'Tosca': [],
    'Prince': [],
    'Cielo': [],
    'Racer': [],
    'Arcadia': [],
  },
  'Ravon': {
    'R4': [],
    'Nexia R3': [],
    'Gentra': [],
    'Nexia R2': [],
    'R2': [],
    'Matiz': [],
  },
  'UzAuto': {
    'Matiz': [],
    'Nexia': [],
    'Lacetti': [],
    'Gentra': [],
    'Damas': [],
    'Labo': [],
  },
  'Chery': {
    'Tiggo 2': [],
    'Tiggo 3': [],
    'Tiggo 4': [],
    'Tiggo 5': [],
    'Tiggo 7': [],
    'Tiggo 8': [],
    'Tiggo 9': [],
    'Tiggo 7 Pro': [],
    'Tiggo 8 Pro': [],
    'Arrizo 5': [],
    'Arrizo 6': [],
    'Arrizo 7': [],
    'Amulet': [],
    'Bonus': [],
    'Kimo': [],
    'QQ': [],
    'Eastar': [],
    'Fulwin': [],
    'Very': [],
    'Jaggi': [],
    'M11': [],
    'Exeed TXL': [],
    'Omoda 5': [],
    'Omoda 9': [],
  },
  'Geely': {
    'Coolray': [],
    'Emgrand': [],
    'Atlas': [],
    'Emgrand X7': [],
    'Emgrand EC7': [],
    'Emgrand GT': [],
    'Tugella': [],
    'Monjaro': [],
    'Okavango': [],
    'MK': [],
    'MK Cross': [],
    'Vision': [],
    'Otaka': [],
    'Geometry C': [],
    'Geometry A': [],
    'Preface': [],
    'Binyue': [],
    'Okavango Pro': [],
    'Panda': [],
  },
  'Haval': {
    'H6': [],
    'Jolion': [],
    'H9': [],
    'H2': [],
    'H3': [],
    'H4': [],
    'H5': [],
    'H7': [],
    'H8': [],
    'F7': [],
    'F7x': [],
    'Dargo': [],
    'M6': [],
    'Hover': [],
  },
  'BYD': {
    'F3': [],
    'F0': [],
    'F6': [],
    'S6': [],
    'S7': [],
    'Song': [],
    'Song Plus': [],
    'Song Pro': [],
    'Tang': [],
    'Han': [],
    'Yuan': [],
    'Dolphin': [],
    'Seal': [],
    'Atto 3': [],
    'Qin': [],
    'Destroyer 05': [],
    'Chazor': [],
    'Seagull': [],
    'Shark': [],
  },
  'Great Wall': {
    'Hover': [],
    'Wingle': [],
    'Safe': [],
    'Haval H3': [],
    'Haval H5': [],
    'Florid': [],
    'Voleex C10': [],
    'Voleex C30': [],
    'Pegasus': [],
    'Deer': [],
    'Sailor': [],
    'Poer': [],
  },
  'Changan': {
    'CS35': [],
    'CS35 Plus': [],
    'CS55': [],
    'CS75': [],
    'CS75 Plus': [],
    'CS85': [],
    'CS95': [],
    'UNI-K': [],
    'UNI-T': [],
    'UNI-V': [],
    'Alsvin': [],
    'Eado': [],
    'Benni': [],
    'Star': [],
    'Hunter': [],
    'Lingxuan': [],
    'Oshan X7': [],
    'Raeton': [],
    'Eado Plus': [],
    'Oushang': [],
    'Yidong': [],
    'Lingyue': [],
    'X7': [],
  },
  'JAC': {
    'J3': [],
    'J4': [],
    'J5': [],
    'J6': [],
    'J7': [],
    'S2': [],
    'S3': [],
    'S4': [],
    'S5': [],
    'S7': [],
    'T6': [],
    'T8': [],
    'T40': [],
    'Refine': [],
    'Rein': [],
    'Sei 2': [],
    'Sei 3': [],
    'Sei 4': [],
    'Sei 7': [],
    'Hunter': [],
  },
  'FAW': {
    'Besturn': [],
    'Oley': [],
    'Vita': [],
    'V5': [],
    'V2': [],
    'Jiefang': [],
    'Bestune T77': [],
    'Bestune B70': [],
    'Bestune T99': [],
    'Hongqi': [],
    'Sirius': [],
    'Xiali': [],
    'Tianjin': [],
    'Bestune': [],
  },
  'Dongfeng': {
    'Glory': [],
    'H30': [],
    'S30': [],
    'S50': [],
    'Rich': [],
    'Captain': [],
    'Forthing': [],
    'Aeolus': [],
    'Fengshen': [],
    'AX7': [],
    'S500': [],
    'EX7': [],
    'Shine': [],
    'Yixuan': [],
    'Rich 6': [],
    'Kaiyun': [],
    'Joyear': [],
  },
  'Exeed': {
    'TXL': [],
    'VX': [],
    'LX': [],
    'RX': [],
    'TX': [],
  },
  'Zotye': {
    'T600': [],
    'Z300': [],
    'Z200': [],
    'M300': [],
    'T700': [],
    'Nomad': [],
    'Z500': [],
    'Z700': [],
    'T300': [],
  },
  'Lifan': {
    'Solano': [],
    'X60': [],
    'X50': [],
    'X70': [],
    'Breez': [],
    'Smily': [],
    '620': [],
    '520': [],
    '320': [],
    '720': [],
    'Cebrium': [],
    'Myway': [],
    'Celliya': [],
  },
  'Foton': {
    'Tunland': [],
    'Tunland G7': [],
    'Aumark': [],
    'Sauvana': [],
    'View': [],
    'Toano': [],
    'Gratour': [],
    'Tunland G9': [],
    'Auman': [],
  },
  'MG': {
    'MG3': [],
    'MG5': [],
    'MG6': [],
    'MG7': [],
    'ZS': [],
    'HS': [],
    'GS': [],
    'RX5': [],
    'RX8': [],
    'TF': [],
    'ZR': [],
    'ZT': [],
    '3': [],
    '5': [],
    '6': [],
    '7': [],
    'Hector': [],
    'Marvel R': [],
    'Cyberster': [],
    '4': [],
  },
  'SsangYong': {
    'Actyon': [],
    'Kyron': [],
    'Rexton': [],
    'Musso': [],
    'Korando': [],
    'Tivoli': [],
    'Rodius': [],
    'Chairman': [],
    'Turismo': [],
    'Torres': [],
    'Istana': [],
    'Stavic': [],
    'Kallista': [],
    'Ssangyong Rexton': [],
  },
  'Maserati': {
    'Ghibli': [],
    'Quattroporte': [],
    'Levante': [],
    'GranTurismo': [],
    'GranCabrio': [],
    'MC20': [],
    'Grecale': [],
    'Coupe': [],
  },
  'Ferrari': {
    '488': [],
    'F8': [],
    '812': [],
    'Roma': [],
    'Portofino': [],
    'California': [],
    '458': [],
    '599': [],
    '360': [],
    '355': [],
    'F355': [],
    'Purosangue': [],
    'SF90': [],
    'LaFerrari': [],
  },
  'Lamborghini': {
    'Huracan': [],
    'Aventador': [],
    'Urus': [],
    'Gallardo': [],
    'Murcielago': [],
    'Revuelto': [],
  },
  'Bentley': {
    'Continental': [],
    'Bentayga': [],
    'Flying Spur': [],
    'Mulsanne': [],
    'Arnage': [],
  },
  'Rolls-Royce': {
    'Phantom': [],
    'Ghost': [],
    'Cullinan': [],
    'Wraith': [],
    'Dawn': [],
    'Spectre': [],
  },
  'Aston Martin': {
    'DB11': [],
    'DBS': [],
    'Vantage': [],
    'DBX': [],
    'Vanquish': [],
    'Rapide': [],
  },
  'Acura': {
    'MDX': [],
    'RDX': [],
    'TLX': [],
    'TSX': [],
    'ILX': [],
    'RL': [],
    'TL': [],
    'NSX': [],
    'ZDX': [],
  },
};

/// Годы выпуска: от нового к старым.
final _carYears = [for (var y = 2026; y >= 1970; y--) '$y'];

/// Подача объявления: категория, описание, цена, город, фото и для авто — характеристики.
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key, this.listing});

  /// Если передано — экран открывается для правки уже опубликованного объявления.
  final Map<String, dynamic>? listing;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final List<XFile> _photos = [];

  // Характеристики автомобиля
  final _yearCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _engineCtrl = TextEditingController();
  final _generationCtrl = TextEditingController();
  final _trimCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  String? _bodyType;
  String? _fuel;
  String? _gearbox;
  String? _drive;
  String? _wheel;
  String? _condition;

  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;
  int? _categoryId;
  bool _saving = false;
  int _days = 14;
  String? _error;

  bool get _isAuto => _categories.any((c) => c['id'] == _categoryId && c['slug'] == 'auto');

  @override
  void initState() {
    super.initState();
    if (widget.listing != null) _prefill();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _priceCtrl,
      _cityCtrl,
      _addressCtrl,
      _brandCtrl,
      _modelCtrl,
      _yearCtrl,
      _mileageCtrl,
      _engineCtrl,
      _generationCtrl,
      _trimCtrl,
      _colorCtrl,
      _vinCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Режим правки: заполняем поля уже опубликованного объявления.
  void _prefill() {
    final l = widget.listing!;
    final price = num.tryParse('${l['price']}');
    _titleCtrl.text = (l['title'] as String?) ?? '';
    _descCtrl.text = (l['description'] as String?) ?? '';
    _priceCtrl.text = price == null ? '' : (price % 1 == 0 ? price.toStringAsFixed(0) : '$price');
    _cityCtrl.text = (l['city'] as String?) ?? '';
    _addressCtrl.text = (l['address'] as String?) ?? '';
    _categoryId = l['category_id'] as int?;
    final d = Map<String, dynamic>.from((l['details'] as Map?) ?? {});
    String s(String k) => '${d[k] ?? ''}';
    _brandCtrl.text = s('brand');
    _modelCtrl.text = s('model');
    _yearCtrl.text = s('year');
    _mileageCtrl.text = s('mileage_km');
    _engineCtrl.text = s('engine_volume');
    _generationCtrl.text = s('generation');
    _trimCtrl.text = s('trim');
    _colorCtrl.text = s('color');
    _vinCtrl.text = s('vin');
    _bodyType = d['body_type'] as String?;
    _fuel = d['fuel'] as String?;
    _gearbox = d['gearbox'] as String?;
    _drive = d['drive'] as String?;
    _wheel = d['steering'] as String?;
    _condition = d['condition'] as String?;
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, slug, name_ru')
          .order('id');
      if (mounted) setState(() => _categories = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      // Список останется пустым, пользователь увидит подсказку.
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked.take(5 - _photos.length)));
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _saving = false;
    });
  }

  String _daysWord(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m100 >= 11 && m100 <= 14) return 'дней';
    if (m10 == 1) return 'день';
    if (m10 >= 2 && m10 <= 4) return 'дня';
    return 'дней';
  }

  /// Название авто как на Авито: «Марка Модель объём КПП, год».
  String _autoTitle() {
    const gearShort = {'Автомат': 'AT', 'Механика': 'MT', 'Робот': 'RT', 'Вариатор': 'CVT'};
    final head = [
      _brandCtrl.text.trim(),
      _modelCtrl.text.trim(),
      _engineCtrl.text.trim(),
      if (_gearbox != null) gearShort[_gearbox] ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    final year = _yearCtrl.text.trim();
    if (head.isEmpty) return year;
    return year.isEmpty ? head : '$head, $year';
  }

  /// Выпадающий список, который не падает, если сохранённого значения нет в списке.
  Widget _pick(String hint, String current, List<String> items, ValueChanged<String> onChanged) {
    return _drop(hint, items.contains(current) ? current : null, items, (v) => onChanged(v ?? ''));
  }

  /// Характеристики авто: заполненные поля, пустые не сохраняем.
  Map<String, dynamic> _carDetails() {
    final m = <String, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) m[key] = value.trim();
    }

    put('brand', _brandCtrl.text);
    put('model', _modelCtrl.text);
    put('year', _yearCtrl.text);
    put('mileage_km', _mileageCtrl.text);
    put('body_type', _bodyType);
    put('fuel', _fuel);
    put('engine_volume', _engineCtrl.text);
    put('gearbox', _gearbox);
    put('drive', _drive);
    put('steering', _wheel);
    put('condition', _condition);
    put('generation', _generationCtrl.text);
    put('trim', _trimCtrl.text);
    put('color', _colorCtrl.text);
    put('vin', _vinCtrl.text.toUpperCase());
    return m;
  }

  /// Удаление: объявление скрывается (статус «hidden»), данные не теряются.
  Future<void> _delete() async {
    final id = widget.listing!['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: const Text('Оно пропадёт из поиска и с вашего профиля.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('listings').update({'status': 'hidden'}).eq('id', id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _fail('Не удалось удалить. Попробуйте снова');
    }
  }

  Future<void> _submit() async {
    final title = _isAuto ? _autoTitle() : _titleCtrl.text.trim();
    final price = num.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return _fail('Войдите, чтобы подать объявление');
    if (_categoryId == null) return _fail('Выберите категорию');
    if (title.length < 3) return _fail('Название — от 3 символов');
    if (price == null || price < 0) return _fail('Укажите цену числом');
    if (_cityCtrl.text.trim().isEmpty) return _fail('Выберите город');
    if (widget.listing == null && _photos.isEmpty) return _fail('Добавьте хотя бы одно фото');
    if (_isAuto) {
      if (_brandCtrl.text.isEmpty) return _fail('Выберите марку автомобиля');
      if (_modelCtrl.text.isEmpty) return _fail('Выберите модель');
      final yearText = _yearCtrl.text.trim();
      final year = int.tryParse(yearText);
      if (yearText.isNotEmpty && (year == null || year < 1950 || year > 2030)) {
        return _fail('Год выпуска — число от 1950 до 2030');
      }
      final vin = _vinCtrl.text.trim();
      if (vin.isNotEmpty && vin.length != 17) return _fail('VIN — ровно 17 символов');
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      final editing = widget.listing;
      if (editing != null) {
        // Правка: фото не меняем, обновляем только текстовые поля и характеристики.
        await db.from('listings').update({
          'status': 'moderation',
          'category_id': _categoryId,
          'title': title,
          'description': _descCtrl.text.trim(),
          'price': price,
          'city': _cityCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'details': _isAuto ? _carDetails() : null,
        }).eq('id', editing['id'] as String);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      final row = await db
          .from('listings')
          .insert({
            'user_id': user.id,
            'category_id': _categoryId,
            'title': title,
            'description': _descCtrl.text.trim(),
            'price': price,
            'currency': 'TJS',
            'city': _cityCtrl.text.trim(),
            'address': _addressCtrl.text.trim(),
            'details': _isAuto ? _carDetails() : null,
            'status': 'moderation',
            'expires_at': DateTime.now().toUtc().add(Duration(days: _days)).toIso8601String(),
          })
          .select('id')
          .single();
      final listingId = row['id'] as String;

      for (var i = 0; i < _photos.length; i++) {
        final bytes = await _photos[i].readAsBytes();
        final path = '${user.id}/$listingId/$i.jpg';
        await db.storage.from('listing-photos').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        await db.from('listing_images').insert({
          'listing_id': listingId,
          'path': path,
          'position': i,
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _fail('Не удалось опубликовать. Проверьте сеть и попробуйте снова');
    }
  }

  Widget _field(TextEditingController c, String hint, {TextInputType? type, int? maxLength, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLength: maxLength,
      onChanged: onChanged,
      decoration: InputDecoration(hintText: hint, counterText: ''),
    );
  }

  Widget _drop(String hint, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$hint-$value'),
      initialValue: value,
      hint: Text(hint),
      items: [for (final i in items) DropdownMenuItem<String>(value: i, child: Text(i))],
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  /// Блок «Про автомобиль»: показывается, когда выбрана категория «Авто».
  List<Widget> _carSection() {
    return [
      const SizedBox(height: 20),
      const Text('Про автомобиль', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 4),
      const Text(
        'Марка и модель обязательны, название объявления соберётся из них. Остальное можно не заполнять.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
      ),
      const SizedBox(height: 12),
      _pick('Марка', _brandCtrl.text, _carCatalog.keys.toList(), (v) {
        _brandCtrl.text = v;
        _modelCtrl.text = '';
        _generationCtrl.text = '';
      }),
      const SizedBox(height: 12),
      _pick(
        'Модель',
        _modelCtrl.text,
        _carCatalog[_brandCtrl.text]?.keys.toList() ?? const [],
        (v) {
          _modelCtrl.text = v;
          _generationCtrl.text = '';
        },
      ),
      if ((_carCatalog[_brandCtrl.text]?[_modelCtrl.text] ?? const <String>[]).isNotEmpty) ...[
        const SizedBox(height: 12),
        _pick(
          'Поколение',
          _generationCtrl.text,
          _carCatalog[_brandCtrl.text]![_modelCtrl.text]!,
          (v) => _generationCtrl.text = v,
        ),
      ],
      const SizedBox(height: 12),
      _pick('Год выпуска', _yearCtrl.text, _carYears, (v) => _yearCtrl.text = v),
      const SizedBox(height: 12),
      Text(
        'Название: ${_autoTitle()}',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 12),
      _field(_mileageCtrl, 'Пробег, км', type: TextInputType.number),
      const SizedBox(height: 12),
      _drop('Состояние', _condition, _conditions, (v) => _condition = v),
      const SizedBox(height: 12),
      _drop('Тип кузова', _bodyType, _bodyTypes, (v) => _bodyType = v),
      const SizedBox(height: 12),
      _drop('Топливо', _fuel, _fuels, (v) => _fuel = v),
      const SizedBox(height: 12),
      _field(
        _engineCtrl,
        'Объём двигателя, л, например 2.0',
        type: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      _drop('Коробка передач', _gearbox, _gearboxes, (v) => _gearbox = v),
      const SizedBox(height: 12),
      _drop('Привод', _drive, _drives, (v) => _drive = v),
      const SizedBox(height: 12),
      _drop('Руль', _wheel, _wheels, (v) => _wheel = v),
      const SizedBox(height: 12),
      _field(_colorCtrl, 'Цвет'),
      const SizedBox(height: 12),
      _field(_trimCtrl, 'Комплектация или модификация'),
      const SizedBox(height: 12),
      _field(_vinCtrl, 'VIN, 17 символов (не показывается полностью)', maxLength: 17),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listing == null ? 'Подать объявление' : 'Редактировать объявление'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text('Категория', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_loadingCategories)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              hint: const Text('Выберите категорию'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['name_ru'] as String),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          const SizedBox(height: 16),
          if (!_isAuto) ...[
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Название объявления'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Цена, TJS'),
          ),
          const SizedBox(height: 12),
          _drop(
            'Город',
            _cityCtrl.text.isEmpty ? null : _cityCtrl.text,
            [
              ...tajCities,
              if (_cityCtrl.text.isNotEmpty && !tajCities.contains(_cityCtrl.text)) _cityCtrl.text,
            ],
            (v) => _cityCtrl.text = v ?? '',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(hintText: 'Адрес (улица, дом) для карты'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(hintText: 'Описание'),
          ),
          if (_isAuto) ..._carSection(),
          if (widget.listing == null) ...[
          const SizedBox(height: 16),
          Text(
            'Срок объявления: $_days ${_daysWord(_days)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            value: _days.toDouble(),
            min: 7,
            max: 30,
            divisions: 23,
            label: '$_days',
            onChanged: (v) => setState(() => _days = v.round()),
          ),
          const Text(
            'От 7 до 30 дней. По истечении срока объявление снимается с публикации.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Text('Фото (до 5)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Chip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: Text('Фото ${i + 1}'),
                  onDeleted: () => setState(() => _photos.removeAt(i)),
                ),
              if (_photos.length < 5)
                ActionChip(
                  avatar: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Добавить'),
                  onPressed: _pickPhotos,
                ),
            ],
          ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          if (widget.listing != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : _delete,
              child: Text('Удалить объявление', style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(widget.listing == null ? 'Опубликовать' : 'Сохранить'),
          ),
        ],
      ),
    );
  }
}
