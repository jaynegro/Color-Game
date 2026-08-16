export type ChannelState = {
	buff: buffer,
	cursor: number,
	references: { [number]: unknown }?,
	ref_map: { [number]: unknown }?,
	size: number?,
}

export type PacketProps<T> = {
	value: T,
	reliability: ("Reliable" | "Unreliable")?,
	max_per_frame: number?,
}

export type DataType<T> = {
	__T: T?,
	write: (value: T) -> (),
	read: (b: buffer, cursor: number) -> (T, number),
	length: number?,
}

export type ValueFromDataType<T> = T

return nil
