import {
  IconPlane, IconBed, IconHome, IconCar, IconTrain, IconBus, IconBike, IconGasStation,
  IconToolsKitchen, IconCoffee, IconGlass, IconShoppingBag, IconGift, IconTicket,
  IconBuildingBank, IconLuggage, IconBackpack, IconBeach, IconMountain, IconMap,
  IconDeviceMobile, IconPill, IconLeaf, IconBookmark,
} from '@tabler/icons-react';

const ICON_MAP: Record<string, typeof IconPlane> = {
  plane: IconPlane, bed: IconBed, home: IconHome, car: IconCar, train: IconTrain,
  bus: IconBus, bike: IconBike, fuel: IconGasStation, food: IconToolsKitchen,
  coffee: IconCoffee, wine: IconGlass, shopping: IconShoppingBag, gift: IconGift,
  ticket: IconTicket, landmark: IconBuildingBank, luggage: IconLuggage,
  backpack: IconBackpack, beach: IconBeach, mountain: IconMountain, map: IconMap,
  phone: IconDeviceMobile, pill: IconPill, leaf: IconLeaf, bookmark: IconBookmark,
};

export function CategoryIcon({ name, size = 16, color }: { name?: string; size?: number; color?: string }) {
  if (!name) return null;
  const Cmp = ICON_MAP[name];
  if (Cmp) return <Cmp size={size} color={color} stroke={1.75} />;
  return <span style={{ fontSize: size, lineHeight: 1 }}>{name}</span>;
}
