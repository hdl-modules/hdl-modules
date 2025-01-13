// -------------------------------------------------------------------------------------------------
// Copyright (c) Lukas Vik. All rights reserved.
//
// This file is part of the hdl-modules project, a collection of reusable, high-quality,
// peer-reviewed VHDL building blocks.
// https://hdl-modules.com
// https://github.com/hdl-modules/hdl-modules
// -------------------------------------------------------------------------------------------------

#include "include/dma_axi_write_simple_no_copy.h"

namespace fpga {

namespace dma_axi_write_simple {

#ifdef NO_DMA_ASSERT

#define _DMA_ASSERT_TRUE(expression, message) ((void)0)

#else // Not NO_DMA_ASSERT.

// This macro is called by the DMA code to check for runtime errors.
#define _DMA_ASSERT_TRUE(expression, message)                                  \
  {                                                                            \
    if (!static_cast<bool>(expression)) {                                      \
      std::ostringstream diagnostics;                                          \
      diagnostics << "DMA error occurred in " << __FILE__ << ":" << __LINE__   \
                  << ", message: " << message << ".";                          \
      std::string diagnostic_message = diagnostics.str();                      \
      m_assertion_handler(&diagnostic_message);                                \
    }                                                                          \
  }

#endif // NO_DMA_ASSERT.

DmaNoCopy::DmaNoCopy(uintptr_t register_base_address, void *buffer,
                     size_t buffer_size_bytes,
                     bool (*assertion_handler)(const std::string *))
    : m_buffer(reinterpret_cast<volatile uint8_t *>(buffer)),
      m_buffer_size_bytes(buffer_size_bytes),
      m_assertion_handler(assertion_handler),
      registers(fpga_regs::DmaAxiWriteSimple(register_base_address,
                                               assertion_handler)) {
  uintptr_t start_address = reinterpret_cast<uintptr_t>(m_buffer);
  uintptr_t end_address = start_address + m_buffer_size_bytes;

  // FPGA registers are 32 bit.
  // Cast here, if 'uintptr_t' is wider than 32 bits on the platform we are
  // compiling for, this should give a compiler error.
  m_start_address = static_cast<uint32_t>(start_address);
  m_end_address = static_cast<uint32_t>(end_address);
}

void DmaNoCopy::setup_and_enable() {
  _DMA_ASSERT_TRUE(!registers.get_config_enable(),
                   "Tried to enable DMA that is already running");

  registers.set_buffer_start_address(m_start_address);
  registers.set_buffer_end_address(m_end_address);
  registers.set_buffer_read_address(m_start_address);

  registers.set_config_enable(1);
}

Response DmaNoCopy::receive_all_data() {
  return receive_data(1, m_buffer_size_bytes);
}

Response DmaNoCopy::receive_data(size_t min_num_bytes, size_t max_num_bytes) {
  check_status();

  size_t written_address = registers.get_buffer_written_address();
  const size_t read_address =
      m_start_address + m_in_buffer_read_outstanding_address;

  const size_t num_bytes_available =
      (written_address - read_address) % m_buffer_size_bytes;

  if (num_bytes_available < min_num_bytes) {
    // Note that 'num_bytes_available' can be zero sometimes even if we got
    // the 'write_done' interrupt, depending on the timing of things.
    // If in the previous round we got and cleared the interrupt,
    // but a new write finished before we read the 'written_address'.
    // In that case we would read and process all the data, but the interrupt
    // would still have triggered again and triggered another entry into this
    // function.
    return response_zero_bytes;
  }

  // Maximum, given how much is available in the buffer, and the
  // maximum requested by the user.
  const size_t max_num_bytes_to_read_out =
      std::min(num_bytes_available, max_num_bytes);

  size_t result_num_bytes = 0;

  if (written_address < read_address) {
    // Read at most up until the end.
    // Might result in smaller chunks than 'min_num_bytes'.
    // But we have to do that since the result buffer must be continuous.
    // An alternative would be to copy data into a longer buffer.
    const size_t num_bytes_until_end = m_end_address - read_address;
    result_num_bytes = std::min(max_num_bytes_to_read_out, num_bytes_until_end);
  } else {
    // Read as much data as we can.
    // We have guaranteed 'max_num_bytes_to_read_out' of continuous data.
    result_num_bytes = max_num_bytes_to_read_out;
  }

  volatile void *result_data = &m_buffer[m_in_buffer_read_outstanding_address];

  m_in_buffer_read_outstanding_address =
      (m_in_buffer_read_outstanding_address + result_num_bytes) %
      m_buffer_size_bytes;

  return {result_num_bytes, result_data};
}

void DmaNoCopy::done_with_data(size_t num_bytes) {
  if (num_bytes > 0) {
    m_in_buffer_read_done_address =
        (m_in_buffer_read_done_address + num_bytes) % m_buffer_size_bytes;
    registers.set_buffer_read_address(m_start_address +
                                        m_in_buffer_read_done_address);
  }
}

void DmaNoCopy::clear_all_data() {
  size_t written_address = registers.get_buffer_written_address();
  registers.set_buffer_read_address(written_address);
  m_in_buffer_read_outstanding_address = written_address - m_start_address;
  m_in_buffer_read_done_address = m_in_buffer_read_outstanding_address;
}

size_t DmaNoCopy::get_num_bytes_available() {
  // Code is fully duplicated in 'receive_data'.
  size_t written_address = registers.get_buffer_written_address();
  const size_t read_address =
      m_start_address + m_in_buffer_read_outstanding_address;

  const size_t num_bytes_available =
      (written_address - read_address) % m_buffer_size_bytes;

  return num_bytes_available;
}

bool DmaNoCopy::check_status() {
  const uint32_t register_value = registers.get_interrupt_status();
  if (register_value) {
    // Read and then clear status ASAP.
    registers.set_interrupt_status(register_value);

    _DMA_ASSERT_TRUE(
        !registers.get_interrupt_status_write_error_from_value(
            register_value) &&
            !registers
                 .get_interrupt_status_start_address_unaligned_error_from_value(
                     register_value) &&
            !registers
                 .get_interrupt_status_end_address_unaligned_error_from_value(
                     register_value) &&
            !registers
                 .get_interrupt_status_read_address_unaligned_error_from_value(
                     register_value),
        "Got error interrupt from the FPGA AXI DMA write module: "
            << register_value);
  }

  return registers.get_interrupt_status_write_done_from_value(register_value);
}

} // namespace dma_axi_write_simple

} // namespace fpga
