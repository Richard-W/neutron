/*
 * This file is part of the neutron project.
 * 
 * Copyright 2013 Richard Wiedenhöft <richard.wiedenhoeft@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Used by entities with transfer_encoding = TransferEncoding.CHUNKED
 */
private class Neutron.Http.ChunkConverter : Object, Converter {
	private bool finished = false;

	public void reset() {
		return;
	}

	public ConverterResult convert(uint8[] inbuf, uint8[] outbuf, ConverterFlags flags, out size_t bytes_read, out size_t bytes_written) throws Error {
		ConverterResult result = ConverterResult.CONVERTED;

		string hexlen = "%x".printf(inbuf.length);
		if(outbuf.length < (inbuf.length + hexlen.length + 4)) throw new IOError.NO_SPACE("outbuf must be larger");

		Memory.set((void*)outbuf, 0, outbuf.length);

		if(flags == ConverterFlags.FLUSH) {
			result = ConverterResult.FLUSHED;
		}
		else if(flags == ConverterFlags.INPUT_AT_END) {
			if(finished) {
				bytes_read = 0;
				bytes_written = 0;
				return ConverterResult.ERROR;
			}
			finished = true;
			result = ConverterResult.FINISHED;
			if(outbuf.length < (inbuf.length + hexlen.length + 9)) throw new IOError.NO_SPACE("outbuf must be larger");
		}

		Memory.copy((void*) outbuf, (void*) hexlen, (size_t) hexlen.length);
		outbuf[hexlen.length] = (uint8) '\r';
		outbuf[hexlen.length+1] = (uint8) '\n';

		Memory.copy((void*) (((uint8*) outbuf) + 2 + hexlen.length), (void*) inbuf, inbuf.length);

		outbuf[hexlen.length + inbuf.length + 2] = '\r';
		outbuf[hexlen.length + inbuf.length + 3] = '\n';

		bytes_read = (size_t) inbuf.length;
		bytes_written = (size_t) (hexlen.length + inbuf.length + 4);

		if(flags == ConverterFlags.INPUT_AT_END && inbuf.length > 0) {
			outbuf[hexlen.length + inbuf.length + 4] = '0';
			outbuf[hexlen.length + inbuf.length + 5] = '\r';
			outbuf[hexlen.length + inbuf.length + 6] = '\n';
			outbuf[hexlen.length + inbuf.length + 7] = '\r';
			outbuf[hexlen.length + inbuf.length + 8] = '\n';

			bytes_written += 5;
		}
		
		return result;
	}
}

