export const normalizeObj = (record: Record<string, any>): Record<string, any> => {
    const converted: Record<string, any> = {}
    for (const [key, value] of Object.entries(record)) {
        const camelKey = toCamelCase(key)
        if (typeof value === 'string') {
            if (!isNaN(Number(value)) && value !== '') {
                converted[camelKey] = Number(value)
            }
            else if (value === 'true') {
                converted[camelKey] = true
            }
            else if (value === 'false') {
                converted[camelKey] = false
            }
            else if (value === 'null') {
                converted[camelKey] = null
            }
            else {
                converted[camelKey] = value
            }
        } else {
            converted[camelKey] = value
        }
    }
    return converted
}

const toCamelCase = (str: string): string => {
    return str.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase())
}
