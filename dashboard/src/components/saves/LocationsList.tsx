export type LocationsByDevice = Array<[string, { name: string; paths: string[] }]>;

export function LocationsList({ locationsByDevice }: { locationsByDevice: LocationsByDevice }) {
  return (
    <ul className="space-y-2">
      {locationsByDevice.map(([deviceId, { name, paths }]) => (
        <li key={deviceId}>
          <span className="font-medium">{name}</span>
          <ul className="mt-1 ml-2 space-y-0.5 text-sm">
            {paths.map((path, i) => (
              <li key={`${deviceId}-${i}`} className="truncate">
                {path}
              </li>
            ))}
          </ul>
        </li>
      ))}
    </ul>
  );
}
