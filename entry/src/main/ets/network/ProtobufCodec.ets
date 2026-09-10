/*
 * TiebaPura - HarmonyOS 原生 ArkTS 实现的第三方百度贴吧客户端
 * Copyright (C) 2026 a307608689-afk
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import { util } from '@kit.ArkTS';

export class ProtoWriter {
  private bytes: number[] = [];

  writeVarint(fieldNumber: number, value: number): void {
    this.writeKey(fieldNumber, 0);
    this.writeRawVarint(value);
  }

  writeBool(fieldNumber: number, value: boolean): void {
    this.writeVarint(fieldNumber, value ? 1 : 0);
  }

  writeString(fieldNumber: number, value: string): void {
    const data = new util.TextEncoder().encode(value);
    this.writeKey(fieldNumber, 2);
    this.writeRawVarint(data.length);
    for (const byte of data) {
      this.bytes.push(byte);
    }
  }

  writeMessage(fieldNumber: number, message: ArrayBuffer): void {
    const data = new Uint8Array(message);
    this.writeKey(fieldNumber, 2);
    this.writeRawVarint(data.length);
    for (const byte of data) {
      this.bytes.push(byte);
    }
  }

  writeDouble(fieldNumber: number, value: number): void {
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setFloat64(0, value, true);
    this.writeKey(fieldNumber, 1);
    const data = new Uint8Array(buffer);
    for (const byte of data) {
      this.bytes.push(byte);
    }
  }

  toArrayBuffer(): ArrayBuffer {
    const output = new Uint8Array(this.bytes.length);
    for (let index = 0; index < this.bytes.length; index += 1) {
      output[index] = this.bytes[index];
    }
    return output.buffer;
  }

  private writeKey(fieldNumber: number, wireType: number): void {
    this.writeRawVarint((fieldNumber << 3) | wireType);
  }

  private writeRawVarint(value: number): void {
    let current = Math.max(0, Math.floor(value));
    while (current > 127) {
      this.bytes.push((current & 127) | 128);
      current = Math.floor(current / 128);
    }
    this.bytes.push(current & 127);
  }
}

export interface ProtoTag {
  fieldNumber: number;
  wireType: number;
}

export class ProtoReader {
  private bytes: Uint8Array;
  private offset: number = 0;

  constructor(data: ArrayBuffer) {
    this.bytes = new Uint8Array(data);
  }

  get position(): number {
    return this.offset;
  }

  get length(): number {
    return this.bytes.length;
  }

  readTag(): ProtoTag | null {
    if (!this.hasNext()) {
      return null;
    }
    const key = this.readVarint();
    return {
      fieldNumber: Math.floor(key / 8),
      wireType: key & 7,
    };
  }

  readVarint(): number {
    let result = 0;
    let shift = 0;
    while (this.offset < this.bytes.length && shift <= 63) {
      const byte = this.bytes[this.offset++];
      result += (byte & 127) * Math.pow(2, shift);
      if ((byte & 128) === 0) {
        return result;
      }
      shift += 7;
    }
    return result;
  }

  readBool(): boolean {
    return this.readVarint() !== 0;
  }

  readString(): string {
    return new util.TextDecoder().decode(new Uint8Array(this.readBytes()));
  }

  readBytes(): ArrayBuffer {
    const length = this.readVarint();
    const safeLength = Math.max(0, Math.min(length, this.bytes.length - this.offset));
    const result = this.bytes.slice(this.offset, this.offset + safeLength);
    this.offset += safeLength;
    return result.buffer;
  }

  readFixed32(): number {
    if (this.offset + 4 > this.bytes.length) {
      this.offset = this.bytes.length;
      return 0;
    }
    const value = (this.bytes[this.offset])
      | (this.bytes[this.offset + 1] << 8)
      | (this.bytes[this.offset + 2] << 16)
      | (this.bytes[this.offset + 3] * 16777216);
    this.offset += 4;
    return value;
  }

  readFixed64(): number {
    let value = 0;
    for (let index = 0; index < 8 && this.offset < this.bytes.length; index += 1) {
      value += this.bytes[this.offset++] * Math.pow(2, index * 8);
    }
    return value;
  }

  skip(wireType: number): void {
    if (wireType === 0) {
      this.readVarint();
    } else if (wireType === 1) {
      this.offset = Math.min(this.bytes.length, this.offset + 8);
    } else if (wireType === 2) {
      const length = this.readVarint();
      this.offset = Math.min(this.bytes.length, this.offset + Math.max(0, length));
    } else if (wireType === 5) {
      this.offset = Math.min(this.bytes.length, this.offset + 4);
    } else {
      this.offset = this.bytes.length;
    }
  }

  hasNext(): boolean {
    return this.offset < this.bytes.length;
  }
}
